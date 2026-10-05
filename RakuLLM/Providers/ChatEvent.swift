import Foundation

public struct Usage: Codable, Equatable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cachedInputTokens: Int
    public var reasoningTokens: Int

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cachedInputTokens: Int = 0,
        reasoningTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
        self.reasoningTokens = reasoningTokens
    }

    public var totalTokens: Int {
        inputTokens + outputTokens
    }
}

public enum ChatEvent: Equatable {
    case textDelta(String)
    case thinking(String)
    case usage(Usage)
    case toolCall(name: String, argumentsJSON: String, callID: String)
    case done
}
