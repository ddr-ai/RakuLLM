import Foundation

public struct ToolScoringResult: Equatable {
    public let tool: ChatToolDefinition
    public let score: Double
}

public struct ToolAdmissionResult: Equatable {
    public let admittedTools: [ChatToolDefinition]
    public let withheldToolNames: [String]
    public let totalSchemaBytes: Int
}

public final class IntentRouter {
    public static let shared = IntentRouter()

    public init() {}

    /// Scores tools by token/word overlap with user prompt
    public func scoreTools(tools: [ChatToolDefinition], prompt: String) -> [ToolScoringResult] {
        let promptTokens = tokenize(prompt)
        guard !promptTokens.isEmpty else {
            return tools.map { ToolScoringResult(tool: $0, score: 0.0) }
        }

        var results: [ToolScoringResult] = []

        for tool in tools {
            let toolText = "\(tool.name) \(tool.description)".lowercased()
            let toolTokens = tokenize(toolText)

            var matchCount = 0
            for pt in promptTokens {
                if toolTokens.contains(pt) {
                    matchCount += 1
                }
            }

            let score = Double(matchCount) / Double(promptTokens.count)
            results.append(ToolScoringResult(tool: tool, score: score))
        }

        return results.sorted { $0.score > $1.score }
    }

    /// T7 Tool-schema budget:
    /// Admitted best-first until schema tokens reach min(8 KB, windowBudget / 4).
    /// Returns admitted tools and withheld names.
    public func admitToolsWithinBudget(
        tools: [ChatToolDefinition],
        prompt: String,
        windowBudget: Int
    ) -> ToolAdmissionResult {
        let scored = scoreTools(tools: tools, prompt: prompt)
        let maxAllowedBytes = min(8 * 1024, (windowBudget / 4) * 4) // approx 4 bytes per token

        var admitted: [ChatToolDefinition] = []
        var withheld: [String] = []
        var currentBytes = 0

        for item in scored {
            let tool = item.tool
            let schemaSize = tool.name.utf8.count + tool.description.utf8.count + tool.inputSchemaJSON.utf8.count
            if currentBytes + schemaSize <= maxAllowedBytes {
                admitted.append(tool)
                currentBytes += schemaSize
            } else {
                withheld.append(tool.name)
            }
        }

        return ToolAdmissionResult(
            admittedTools: admitted,
            withheldToolNames: withheld,
            totalSchemaBytes: currentBytes
        )
    }

    private func tokenize(_ text: String) -> Set<String> {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
        return Set(words)
    }
}
