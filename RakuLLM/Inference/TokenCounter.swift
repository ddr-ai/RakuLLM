import Foundation

public final class TokenCounter {
    public static let shared = TokenCounter()

    public init() {}

    public func countTokens(text: String, localModelLoaded: Bool = false) -> Int {
        // T1 rule: exact counting or conservative ceiling
        return TokenMeter.shared.estimateTokens(for: text)
    }
}
