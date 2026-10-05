import Foundation

public struct ModelPricing: Codable, Equatable {
    public var promptPerMillion: Double
    public var completionPerMillion: Double
    public var cachedPromptPerMillion: Double

    public init(
        promptPerMillion: Double,
        completionPerMillion: Double,
        cachedPromptPerMillion: Double = 0.0
    ) {
        self.promptPerMillion = promptPerMillion
        self.completionPerMillion = completionPerMillion
        self.cachedPromptPerMillion = cachedPromptPerMillion
    }
}

public final class CostTable: ObservableObject {
    public static let shared = CostTable()

    @Published public var effectiveDate: String
    @Published public var pricingMap: [String: ModelPricing]

    public init() {
        self.effectiveDate = "2026-10-01"
        self.pricingMap = [
            // Gemini
            "gemini-2.5-flash": ModelPricing(promptPerMillion: 0.075, completionPerMillion: 0.30, cachedPromptPerMillion: 0.01875),
            "gemini-1.5-pro": ModelPricing(promptPerMillion: 1.25, completionPerMillion: 5.00, cachedPromptPerMillion: 0.3125),

            // OpenAI
            "gpt-4o": ModelPricing(promptPerMillion: 2.50, completionPerMillion: 10.00, cachedPromptPerMillion: 1.25),
            "gpt-4o-mini": ModelPricing(promptPerMillion: 0.15, completionPerMillion: 0.60, cachedPromptPerMillion: 0.075),

            // Grok
            "grok-2-latest": ModelPricing(promptPerMillion: 2.00, completionPerMillion: 10.00),

            // Anthropic
            "claude-3-5-sonnet-20241022": ModelPricing(promptPerMillion: 3.00, completionPerMillion: 15.00, cachedPromptPerMillion: 0.30),
            "claude-3-5-haiku-20241022": ModelPricing(promptPerMillion: 0.80, completionPerMillion: 4.00, cachedPromptPerMillion: 0.08),

            // Local models
            "local-gguf": ModelPricing(promptPerMillion: 0.0, completionPerMillion: 0.0)
        ]
    }

    public func calculateCost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cachedTokens: Int = 0
    ) -> Double {
        // Match specific or fallback to prefix
        let pricing = pricingMap[model] ?? pricingMap.first(where: { model.hasPrefix($0.key) })?.value
        guard let p = pricing else { return 0.0 }

        let uncachedInput = max(0, inputTokens - cachedTokens)
        let costInput = (Double(uncachedInput) / 1_000_000.0) * p.promptPerMillion
        let costCached = (Double(cachedTokens) / 1_000_000.0) * p.cachedPromptPerMillion
        let costOutput = (Double(outputTokens) / 1_000_000.0) * p.completionPerMillion

        return costInput + costCached + costOutput
    }
}
