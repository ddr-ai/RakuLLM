import XCTest
@testable import RakuLLM

final class JSONSchemaGrammarTests: XCTestCase {
    let converter = JSONSchemaGrammar.shared

    func testPrimitiveConversions() {
        let stringRules = converter.convertSchema(["type": "string"], ruleName: "test-str")
        XCTAssertTrue(stringRules.contains("test-str ::= string"))

        let intRules = converter.convertSchema(["type": "integer"], ruleName: "test-int")
        XCTAssertTrue(intRules.contains("test-int ::= integer"))

        let boolRules = converter.convertSchema(["type": "boolean"], ruleName: "test-bool")
        XCTAssertTrue(boolRules.contains("test-bool ::= boolean"))
    }

    func testEnumConversion() {
        let enumSchema: [String: Any] = [
            "type": "string",
            "enum": ["asc", "desc"]
        ]
        let rules = converter.convertSchema(enumSchema, ruleName: "order")
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0], "order ::= \"\\\"asc\\\"\" | \"\\\"desc\\\"\"")
    }

    func testToolGrammarGeneration() {
        let schema = """
        {
            "type": "object",
            "properties": {
                "query": { "type": "string" },
                "limit": { "type": "integer" }
            },
            "required": ["query"]
        }
        """

        let tools = [
            (name: "search_db", schemaJSON: schema),
            (name: "ping", schemaJSON: "{}")
        ]

        let gbnf = converter.generateToolGrammar(tools: tools)

        XCTAssertTrue(gbnf.contains("root ::="))
        XCTAssertTrue(gbnf.contains("\"\\\"tool\\\"\""))
        XCTAssertTrue(gbnf.contains("\"\\\"search_db\\\"\""))
        XCTAssertTrue(gbnf.contains("\"\\\"ping\\\"\""))
        XCTAssertTrue(gbnf.contains("args-0-prop-query"))
    }
}
