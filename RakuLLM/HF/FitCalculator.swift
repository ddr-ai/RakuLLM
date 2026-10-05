import Foundation

public enum FitLevel: String, Codable {
    case fits = "fits"
    case tight = "tight"
    case tooLarge = "tooLarge"

    public var displayName: String {
        switch self {
        case .fits: return "Fits"
        case .tight: return "Tight"
        case .tooLarge: return "Too Large"
        }
    }
}

public struct ModelFitAssessment: Equatable {
    public let fitLevel: FitLevel
    public let requiredBytes: UInt64
    public let availableBudgetBytes: UInt64
    public let referenceContext: Int
    public let detail: String
}

public final class FitCalculator {
    public static let shared = FitCalculator()
    public static let referenceContext: Int = 4096

    public init() {}

    /// Computes approximate KV cache requirement for reference context (4096).
    /// Typically 32 layers * 32 heads * 128 head_dim * 2 * 2 bytes ~= 512 MB to 1 GB.
    public func estimateKVBytes(nCtx: Int = referenceContext, approxParamsMillions: Int = 3000) -> UInt64 {
        // Standard conservative KV estimate: 512 MB for ~3B models at 4096 context
        let baseMB: Double = Double(nCtx) / 4096.0 * 512.0
        return UInt64(baseMB * 1024.0 * 1024.0)
    }

    /// Evaluates if a model file fits on device memory.
    /// D7 / §8.3:
    /// per GGUF file, fileSize + kvEstimate(4096) <= available * 0.60 is fits;
    /// at 85% of that it is tight; otherwise too large.
    public func assessFit(
        fileSizeBytes: Int64,
        availableMemoryBytes: UInt64
    ) -> ModelFitAssessment {
        let budget = UInt64(Double(availableMemoryBytes) * 0.60)
        let kvBytes = estimateKVBytes(nCtx: FitCalculator.referenceContext)
        let totalRequired = UInt64(max(0, fileSizeBytes)) + kvBytes

        let fitLevel: FitLevel
        if totalRequired <= UInt64(Double(budget) * 0.85) {
            fitLevel = .fits
        } else if totalRequired <= budget {
            fitLevel = .tight
        } else {
            fitLevel = .tooLarge
        }

        let reqMB = totalRequired / (1024 * 1024)
        let budgetMB = budget / (1024 * 1024)
        let detail = "Requires ~\(reqMB) MB (weights + 4096 context KV) out of \(budgetMB) MB budget"

        return ModelFitAssessment(
            fitLevel: fitLevel,
            requiredBytes: totalRequired,
            availableBudgetBytes: budget,
            referenceContext: FitCalculator.referenceContext,
            detail: detail
        )
    }
}
