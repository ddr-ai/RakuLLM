import XCTest
@testable import RakuLLM

final class CostTableTests: XCTestCase {
    let costTable = CostTable.shared

    func testCostCalculationGPT4o() {
        // gpt-4o: $2.50 / M input, $10.00 / M output
        let inputTokens = 1000
        let outputTokens = 500
        let cost = costTable.calculateCost(model: "gpt-4o", inputTokens: inputTokens, outputTokens: outputTokens)

        let expectedInput = (1000.0 / 1_000_000.0) * 2.50
        let expectedOutput = (500.0 / 1_000_000.0) * 10.00
        let expectedTotal = expectedInput + expectedOutput

        XCTAssertEqual(cost, expectedTotal, accuracy: 1e-6)
    }

    func testCostCalculationWithCachedTokens() {
        // gemini-2.5-flash: $0.075 / M input, $0.30 / M output, $0.01875 / M cached
        let inputTokens = 10_000
        let cachedTokens = 8_000
        let outputTokens = 2_000

        let cost = costTable.calculateCost(
            model: "gemini-2.5-flash",
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cachedTokens: cachedTokens
        )

        let uncachedCost = (2000.0 / 1_000_000.0) * 0.075
        let cachedCost = (8000.0 / 1_000_000.0) * 0.01875
        let outputCost = (2000.0 / 1_000_000.0) * 0.30
        let expected = uncachedCost + cachedCost + outputCost

        XCTAssertEqual(cost, expected, accuracy: 1e-6)
    }

    func testLocalModelIsZeroCost() {
        let cost = costTable.calculateCost(model: "local-gguf", inputTokens: 50_000, outputTokens: 10_000)
        XCTAssertEqual(cost, 0.0)
    }
}
