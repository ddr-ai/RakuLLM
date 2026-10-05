import XCTest
@testable import RakuLLM

final class FitCalculatorTests: XCTestCase {
    let calculator = FitCalculator.shared

    func testFitBoundaries() {
        // Assume 6 GB available RAM
        let availableMemory: UInt64 = 6 * 1024 * 1024 * 1024
        let budget = UInt64(Double(availableMemory) * 0.60) // 3.6 GB = 3,865,470,566 bytes
        let kv = calculator.estimateKVBytes(nCtx: 4096)     // 512 MB

        // 1. Fits: well below 85% of budget
        let smallFileSize: Int64 = 1 * 1024 * 1024 * 1024 // 1 GB
        let fitAssessment = calculator.assessFit(fileSizeBytes: smallFileSize, availableMemoryBytes: availableMemory)
        XCTAssertEqual(fitAssessment.fitLevel, .fits)
        XCTAssertEqual(fitAssessment.referenceContext, 4096)

        // 2. Tight: between 85% and 100% of budget
        // Target total = 0.90 * budget
        let tightTotal = UInt64(Double(budget) * 0.90)
        let tightFileSize = Int64(tightTotal - kv)
        let tightAssessment = calculator.assessFit(fileSizeBytes: tightFileSize, availableMemoryBytes: availableMemory)
        XCTAssertEqual(tightAssessment.fitLevel, .tight)

        // 3. Too Large: above 100% of budget
        let hugeFileSize: Int64 = 5 * 1024 * 1024 * 1024 // 5 GB
        let tooLargeAssessment = calculator.assessFit(fileSizeBytes: hugeFileSize, availableMemoryBytes: availableMemory)
        XCTAssertEqual(tooLargeAssessment.fitLevel, .tooLarge)
    }
}
