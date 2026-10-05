import Foundation

public final class JSONSchemaGrammar {
    public static let shared = JSONSchemaGrammar()

    public init() {}

    /// Generates a GBNF grammar string that constrains model output to:
    /// {"tool": "<enum of names>", "arguments": <matching tool arguments schema>}
    public func generateToolGrammar(tools: [(name: String, schemaJSON: String)]) -> String {
        var gbnf = [String]()
        gbnf.append("# GBNF Grammar for MCP Tool Calling")
        gbnf.append("root ::= ws \"{\" ws \"\\\"tool\\\"\" ws \":\" ws tool-call ws \"}\" ws")

        if tools.isEmpty {
            gbnf.append("tool-call ::= \"\\\"none\\\"\"")
            appendCommonRules(to: &gbnf)
            return gbnf.joined(separator: "\n")
        }

        var toolBranches: [String] = []
        for (index, tool) in tools.enumerated() {
            let toolRule = "tool-\(index)"
            let argsRule = "args-\(index)"
            toolBranches.append(toolRule)

            gbnf.append("\(toolRule) ::= \"\\\"\(tool.name)\\\"\" ws \",\" ws \"\\\"arguments\\\"\" ws \":\" ws \(argsRule)")

            if let data = tool.schemaJSON.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let rules = convertSchema(json, ruleName: argsRule)
                gbnf.append(contentsOf: rules)
            } else {
                gbnf.append("\(argsRule) ::= object")
            }
        }

        gbnf.append("tool-call ::= " + toolBranches.joined(separator: " | "))
        appendCommonRules(to: &gbnf)

        return gbnf.joined(separator: "\n")
    }

    /// Converts a single JSON Schema object to GBNF rules
    public func convertSchema(_ schema: [String: Any], ruleName: String) -> [String] {
        var rules: [String] = []
        let type = schema["type"] as? String ?? "object"

        if let enumVals = schema["enum"] as? [Any] {
            let options = enumVals.map { val -> String in
                if let str = val as? String {
                    return "\"\\\"\(str)\\\"\""
                } else {
                    return "\"\(val)\""
                }
            }
            rules.append("\(ruleName) ::= \(options.joined(separator: " | "))")
            return rules
        }

        switch type {
        case "string":
            rules.append("\(ruleName) ::= string")

        case "integer":
            rules.append("\(ruleName) ::= integer")

        case "number":
            rules.append("\(ruleName) ::= number")

        case "boolean":
            rules.append("\(ruleName) ::= boolean")

        case "array":
            let itemRule = "\(ruleName)-item"
            if let items = schema["items"] as? [String: Any] {
                let subRules = convertSchema(items, ruleName: itemRule)
                rules.append(contentsOf: subRules)
            } else {
                rules.append("\(itemRule) ::= value")
            }
            rules.append("\(ruleName) ::= \"[\" ws (\(itemRule) (\",\" ws \(itemRule))*)? ws \"]\"")

        case "object":
            let properties = schema["properties"] as? [String: Any] ?? [:]
            let required = schema["required"] as? [String] ?? []
            let additionalProps = schema["additionalProperties"] as? Bool ?? false

            if properties.isEmpty {
                rules.append("\(ruleName) ::= object")
                return rules
            }

            var propRules: [String] = []
            for (key, val) in properties.sorted(by: { $0.key < $1.key }) {
                let subRuleName = "\(ruleName)-prop-\(sanitize(key))"
                if let propSchema = val as? [String: Any] {
                    let subRules = convertSchema(propSchema, ruleName: subRuleName)
                    rules.append(contentsOf: subRules)
                } else {
                    rules.append("\(subRuleName) ::= value")
                }

                let isReq = required.contains(key)
                let kv = "\"\\\"\(key)\\\"\" ws \":\" ws \(subRuleName)"
                if isReq {
                    propRules.append(kv)
                } else {
                    propRules.append("(\(kv))?")
                }
            }

            // Assemble required and optional properties
            let body = propRules.joined(separator: " (ws \",\" ws)? ")
            if additionalProps {
                rules.append("\(ruleName) ::= \"{\" ws (\(body) | kv-pairs)? ws \"}\"")
            } else {
                rules.append("\(ruleName) ::= \"{\" ws (\(body)) ws \"}\"")
            }

        default:
            rules.append("\(ruleName) ::= value")
        }

        return rules
    }

    private func sanitize(_ str: String) -> String {
        str.replacingOccurrences(of: "-", with: "_")
           .replacingOccurrences(of: ".", with: "_")
    }

    private func appendCommonRules(to rules: inout [String]) {
        rules.append("value ::= object | array | string | number | boolean | null")
        rules.append("object ::= \"{\" ws (string ws \":\" ws value (ws \",\" ws string ws \":\" ws value)*)? ws \"}\"")
        rules.append("array ::= \"[\" ws (value (ws \",\" ws value)*)? ws \"]\"")
        rules.append("string ::= \"\\\"\" [^\"\\\\]* \"\\\"\"")
        rules.append("integer ::= \"-\"? [0-9]+")
        rules.append("number ::= \"-\"? [0-9]+ (\".\" [0-9]+)? ([eE] [-+]? [0-9]+)?")
        rules.append("boolean ::= \"true\" | \"false\"")
        rules.append("null ::= \"null\"")
        rules.append("kv-pairs ::= string ws \":\" ws value (ws \",\" ws string ws \":\" ws value)*")
        rules.append("ws ::= [ \\t\\n]*")
    }
}
