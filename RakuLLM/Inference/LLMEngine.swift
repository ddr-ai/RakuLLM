import Foundation

public enum InferenceError: LocalizedError, Equatable {
    case modelNotFound(String)
    case failedToLoadModel(String)
    case contextAllocationFailed
    case contextWindowExceeded(budget: Int, needed: Int)
    case modelNotLoaded
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let path): return "Model file not found at path: \(path)"
        case .failedToLoadModel(let msg): return "Failed to load model: \(msg)"
        case .contextAllocationFailed: return "Could not allocate inference context with the given settings."
        case .contextWindowExceeded(let budget, let needed): return "Context window exceeded: budget is \(budget), request needed \(needed) tokens."
        case .modelNotLoaded: return "No local model is currently loaded."
        case .generationFailed(let msg): return "Local inference generation failed: \(msg)"
        }
    }
}

public protocol LLMEngine: AnyObject, Sendable {
    var isLoaded: Bool { get async }
    var loadedModelID: String? { get async }
    func loadModel(path: String, settings: ModelSettings) async throws
    func unloadModel() async
    func generate(request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error>
    func tokenize(text: String) async -> [Int32]
}
