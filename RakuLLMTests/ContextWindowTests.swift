import XCTest
@testable import RakuLLM

final class ContextWindowTests: XCTestCase {
    let meter = TokenMeter.shared

    func testT1ConservativeEstimate() {
        // Empty text: 4 tokens base
        XCTAssertEqual(meter.estimateTokens(for: ""), 4)

        // 10 chars: ceil(10 / 3.5) + 4 = ceil(2.857) + 4 = 3 + 4 = 7
        XCTAssertEqual(meter.estimateTokens(for: "1234567890"), 7)

        // Always rounds UP
        let est = meter.estimateTokens(for: "Hello World!") // 12 chars: ceil(3.42) + 4 = 4 + 4 = 8
        XCTAssertEqual(est, 8)
    }

    func testT2WindowBudget() {
        // nCtx = 4096, requestedOutput = 2048
        // reserve = min(2048, 4096 / 4) = min(2048, 1024) = 1024
        // budget = 4096 - 1024 = 3072
        let budget = meter.computeBudget(nCtx: 4096, requestedMaxOutputTokens: 2048)
        XCTAssertEqual(budget.reserve, 1024)
        XCTAssertEqual(budget.budget, 3072)
    }

    func testT3WindowingArithmetic() {
        let budget = meter.computeBudget(nCtx: 4096, requestedMaxOutputTokens: 1024)

        let msg1 = ChatRequestMessage(role: "user", content: "Short message 1")
        let msg2 = ChatRequestMessage(role: "assistant", content: "Short response 2")
        let msg3 = ChatRequestMessage(role: "user", content: "Latest query 3")

        let windowed = meter.windowMessages(
            messages: [msg1, msg2, msg3],
            systemPrompt: "System Prompt",
            budget: budget
        )

        XCTAssertTrue(windowed.fitsContext)
        XCTAssertEqual(windowed.includedMessages.count, 3)
        XCTAssertEqual(windowed.prunedCount, 0)
    }

    func testT4ExplicitOutputCap() {
        // n_ctx = 4096, promptTokens = 1000 -> max(256, 4096 - 1000) = 3096
        XCTAssertEqual(meter.computeMaxOutputTokens(nCtx: 4096, promptTokens: 1000), 3096)

        // promptTokens = 4000 -> max(256, 4096 - 4000) = 256
        XCTAssertEqual(meter.computeMaxOutputTokens(nCtx: 4096, promptTokens: 4000), 256)
    }

    func testT6ToolResultTruncationAtUTF8Boundary() {
        // Create 70 KB of text
        let base = String(repeating: "Hello 世界! 🚀 ", count: 4000)
        XCTAssertGreaterThan(base.utf8.count, 64 * 1024)

        let truncated = meter.truncateToolResultIfNeeded(base, maxBytes: 64 * 1024)

        // Must contain truncation notice
        XCTAssertTrue(truncated.contains("[truncated"))
        XCTAssertTrue(truncated.contains("bytes — re-run the tool with a narrower query]"))

        // Must be valid UTF-8
        XCTAssertNotNil(truncated.data(using: .utf8))
    }

    func testT7SchemaBudgetAdmission() {
        let tool1 = ChatToolDefinition(name: "tool_1", description: "First tool", inputSchemaJSON: String(repeating: "a", count: 1000))
        let tool2 = ChatToolDefinition(name: "tool_2", description: "Second tool", inputSchemaJSON: String(repeating: "b", count: 1000))
        let tool3 = ChatToolDefinition(name: "tool_3", description: "Third tool", inputSchemaJSON: String(repeating: "c", count: 8000))

        // windowBudget = 2000 tokens -> min(8KB, (2000/4)*4) = min(8KB, 2KB) = 2048 bytes
        let result = IntentRouter.shared.admitToolsWithinBudget(
            tools: [tool1, tool2, tool3],
            prompt: "tool",
            windowBudget: 2000
        )

        XCTAssertTrue(result.admittedTools.count >= 1)
        XCTAssertTrue(result.totalSchemaBytes <= 2048)
        XCTAssertTrue(result.withheldToolNames.contains("tool_3"))
    }
}
