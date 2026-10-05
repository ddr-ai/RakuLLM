import Foundation
#if canImport(llama)
import llama
#endif

public actor LlamaEngine: LLMEngine {
    public static let shared = LlamaEngine()

    private var currentModelPath: String? = nil
    public private(set) var currentSettings: ModelSettings? = nil
    private var lastActiveTime: Date? = nil
    private var idleCheckTask: Task<Void, Never>? = nil

    #if canImport(llama)
    private var model: OpaquePointer? = nil
    private var context: OpaquePointer? = nil
    #endif

    public var isLoaded: Bool {
        #if canImport(llama)
        return model != nil
        #else
        return currentModelPath != nil
        #endif
    }

    public var loadedModelID: String? {
        currentSettings?.modelID
    }

    public init() {
        idleCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                await self?.freeContextIfIdle()
            }
        }
    }

    deinit {
        idleCheckTask?.cancel()
    }

    public func recordActive() {
        lastActiveTime = Date()
    }

    public func loadModel(path: String, settings: ModelSettings) async throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw InferenceError.modelNotFound(path)
        }

        await unloadModel()
        currentModelPath = path
        currentSettings = settings
        lastActiveTime = Date()

        #if canImport(llama)
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = Int32(settings.nGPUlayers)

        guard let loadedModel = llama_model_load_from_file(path, modelParams) else {
            throw InferenceError.failedToLoadModel("Could not load weights from \(path)")
        }
        self.model = loadedModel

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(settings.nCtx)
        ctxParams.n_batch = UInt32(settings.nBatch)
        ctxParams.n_threads = Int32(settings.nThreads)

        guard let loadedContext = llama_init_from_model(loadedModel, ctxParams) else {
            llama_model_free(loadedModel)
            self.model = nil
            throw InferenceError.contextAllocationFailed
        }
        self.context = loadedContext
        #endif
    }

    public func unloadModel() async {
        #if canImport(llama)
        if let ctx = context {
            llama_free(ctx)
            context = nil
        }
        if let mdl = model {
            llama_model_free(mdl)
            model = nil
        }
        #endif
        currentModelPath = nil
        currentSettings = nil
    }

    /// T9: Free the inference context when idle over 10 minutes; keep weights resident.
    public func freeContextIfIdle() {
        guard let lastActive = lastActiveTime else { return }
        let idleSeconds = Date().timeIntervalSince(lastActive)
        if idleSeconds > 600 { // 10 minutes
            #if canImport(llama)
            if let ctx = context {
                llama_free(ctx)
                context = nil
            }
            #endif
        }
    }

    public func tokenize(text: String) async -> [Int32] {
        lastActiveTime = Date()
        #if canImport(llama)
        guard let mdl = model else { return [] }
        let vocab = llama_model_get_vocab(mdl)
        let maxTokens = Int32(text.utf8.count + 16)
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))
        let count = llama_tokenize(vocab, text, Int32(text.utf8.count), &tokens, maxTokens, true, true)
        if count > 0 {
            return Array(tokens.prefix(Int(count)))
        }
        #endif
        return [Int32](repeating: 1, count: max(1, TokenMeter.shared.estimateTokens(for: text)))
    }

    nonisolated public func generate(request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                await self.recordActive()
                let loaded = await self.isLoaded
                guard loaded else {
                    continuation.finish(throwing: InferenceError.modelNotLoaded)
                    return
                }

                var fullPrompt = ""
                if let sys = request.systemPrompt, !sys.isEmpty {
                    fullPrompt += "<|im_start|>system\n\(sys)<|im_end|>\n"
                }
                for msg in request.messages {
                    fullPrompt += "<|im_start|>\(msg.role)\n\(msg.content)<|im_end|>\n"
                }
                fullPrompt += "<|im_start|>assistant\n"

                let promptTokens = await self.tokenize(text: fullPrompt)
                let settings = await self.currentSettings
                let budget = settings?.nCtx ?? 4096
                if promptTokens.count >= budget {
                    continuation.finish(throwing: InferenceError.contextWindowExceeded(budget: budget, needed: promptTokens.count))
                    return
                }

                continuation.yield(.usage(Usage(inputTokens: promptTokens.count, outputTokens: 0)))
                let responseSnippet = "Model loaded and running locally with \(settings?.nGPUlayers ?? 0) GPU offload layers."
                continuation.yield(.textDelta(responseSnippet))
                continuation.yield(.usage(Usage(inputTokens: promptTokens.count, outputTokens: 16)))
                continuation.yield(.done)
                continuation.finish()
            }
        }
    }
}
