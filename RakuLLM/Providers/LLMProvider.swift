import Foundation

public protocol LLMProvider: Sendable {
    var kind: ProviderKind { get }
    func stream(request: ChatRequest, apiKey: String) -> AsyncThrowingStream<ChatEvent, Error>
    func buildRequestBody(request: ChatRequest) throws -> Data
}

public enum ProviderError: LocalizedError, Equatable {
    case missingAPIKey(ProviderKind)
    case invalidURL
    case httpError(statusCode: Int, responseBody: String)
    case decodingError(String)
    case unsupportedFeature(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let kind):
            return "\(kind.displayName) API key is missing. Please configure it in Settings."
        case .invalidURL:
            return "Invalid provider endpoint URL."
        case .httpError(let code, let body):
            return "HTTP Error \(code): \(body)"
        case .decodingError(let msg):
            return "Failed to decode response: \(msg)"
        case .unsupportedFeature(let msg):
            return "Unsupported feature: \(msg)"
        }
    }
}
