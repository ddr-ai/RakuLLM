import Foundation
#if canImport(llama)
import llama
#endif

public actor LlamaEngine: LLMEngine {
    public static let shared = LlamaEngine()

    #if canImport(llama)
    private static var isBackendInitialized = false
    private static func ensureBackendInit() {
        if !isBackendInitialized {
            llama_backend_init()
            isBackendInitialized = true
        }
    }
    #endif

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
        isLoaded ? (currentSettings?.modelID ?? currentModelPath) : nil
    }

    public init() {
        #if canImport(llama)
        Self.ensureBackendInit()
        #endif
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

        #if canImport(llama)
        Self.ensureBackendInit()
        #endif

        await unloadModel()
        currentModelPath = path
        currentSettings = settings
        lastActiveTime = Date()

        #if canImport(llama)
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = Int32(settings.nGPUlayers)

        var loadedModel = llama_model_load_from_file(path, modelParams)
        if loadedModel == nil && settings.nGPUlayers > 0 {
            // Fallback to CPU execution if Metal/GPU allocation fails
            modelParams.n_gpu_layers = 0
            loadedModel = llama_model_load_from_file(path, modelParams)
        }

        guard let mdl = loadedModel else {
            throw InferenceError.failedToLoadModel("Could not load weights from \(path). The GGUF file may be corrupted, truncated, or invalid.")
        }
        self.model = mdl

        // Try initializing context with requested n_ctx, with progressive fallback for constrained memory
        var loadedContext: OpaquePointer? = nil
        let requestedCtx = UInt32(settings.nCtx)
        let candidates: [UInt32] = [requestedCtx, 2048, 1024, 512].filter { $0 <= requestedCtx }
        let testSizes = candidates.isEmpty ? [requestedCtx] : candidates

        for ctxSize in testSizes {
            var ctxParams = llama_context_default_params()
            ctxParams.n_ctx = ctxSize
            ctxParams.n_batch = min(ctxSize, UInt32(settings.nBatch))
            ctxParams.n_threads = Int32(max(1, settings.nThreads))

            if let ctx = llama_init_from_model(mdl, ctxParams) {
                loadedContext = ctx
                break
            }
        }

        guard let ctx = loadedContext else {
            llama_model_free(mdl)
            self.model = nil
            throw InferenceError.contextAllocationFailed
        }
        self.context = ctx
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
        guard let mdl = model, let vocab = llama_model_get_vocab(mdl) else { return [] }
        let maxTokens = Int32(text.utf8.count + 16)
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))
        let count = llama_tokenize(vocab, text, Int32(text.utf8.count), &tokens, maxTokens, true, true)
        if count > 0 {
            return Array(tokens.prefix(Int(count)))
        }
        #endif
        return [Int32](repeating: 1, count: max(1, TokenMeter.shared.estimateTokens(for: text)))
    }

    #if canImport(llama)
    private func pieceFor(vocab: OpaquePointer, token: llama_token) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        let pieceLen = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, false)
        if pieceLen > 0 {
            let bytes = buf.prefix(Int(pieceLen)).map { UInt8(bitPattern: $0) }
            return String(bytes: bytes, encoding: .utf8) ?? ""
        } else if pieceLen < 0 {
            let needed = Int(-pieceLen)
            var bigBuf = [CChar](repeating: 0, count: needed + 4)
            let pieceLen2 = llama_token_to_piece(vocab, token, &bigBuf, Int32(bigBuf.count), 0, false)
            if pieceLen2 > 0 {
                let bytes = bigBuf.prefix(Int(pieceLen2)).map { UInt8(bitPattern: $0) }
                return String(bytes: bytes, encoding: .utf8) ?? ""
            }
        }
        return ""
    }

    private func runLlamaInference(
        promptTokens: [Int32],
        request: ChatRequest,
        continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation
    ) {
        // Ensure context is available (in case it was freed while idle)
        if self.context == nil, let mdl = self.model, let settings = self.currentSettings {
            var ctxParams = llama_context_default_params()
            ctxParams.n_ctx = UInt32(settings.nCtx)
            ctxParams.n_batch = UInt32(settings.nBatch)
            ctxParams.n_threads = Int32(max(1, settings.nThreads))
            self.context = llama_init_from_model(mdl, ctxParams)
        }

        guard let ctx = self.context,
              let mdl = self.model,
              let vocab = llama_model_get_vocab(mdl) else {
            continuation.finish(throwing: InferenceError.modelNotLoaded)
            return
        }

        // Clear existing memory/KV cache
        if let mem = llama_get_memory(ctx) {
            llama_memory_clear(mem, true)
        }

        // Ingest prompt in batches
        let nBatch = Int(currentSettings?.nBatch ?? 512)
        var prompt = promptTokens
        for chunkStart in stride(from: 0, to: prompt.count, by: nBatch) {
            if Task.isCancelled {
                continuation.finish()
                return
            }
            let chunkEnd = min(chunkStart + nBatch, prompt.count)
            let chunkSize = chunkEnd - chunkStart
            let chunk = Array(prompt[chunkStart..<chunkEnd])
            let decodeRes = chunk.withUnsafeBufferPointer { bufPtr -> Int32 in
                var batch = llama_batch_get_one(UnsafeMutablePointer(mutating: bufPtr.baseAddress!), Int32(chunkSize))
                return llama_decode(ctx, batch)
            }

            if decodeRes != 0 {
                continuation.finish(throwing: InferenceError.generationFailed("Prompt ingestion failed (code \(decodeRes))"))
                return
            }
        }

        guard let sampler = llama_sampler_init_greedy() else {
            continuation.finish(throwing: InferenceError.generationFailed("Sampler initialization failed"))
            return
        }
        defer { llama_sampler_free(sampler) }

        var outputCount = 0
        let maxTokens = min(request.maxOutputTokens, 2048)

        while outputCount < maxTokens {
            if Task.isCancelled { break }

            let nextToken = llama_sampler_sample(sampler, ctx, -1)
            if llama_vocab_is_eog(vocab, nextToken) {
                break
            }
            llama_sampler_accept(sampler, nextToken)

            let piece = pieceFor(vocab: vocab, token: nextToken)
            if !piece.isEmpty {
                continuation.yield(.textDelta(piece))
            }
            outputCount += 1

            var currentToken = nextToken
            var singleBatch = llama_batch_get_one(&currentToken, 1)
            let decodeRes = llama_decode(ctx, singleBatch)
            if decodeRes != 0 {
                break
            }
        }

        continuation.yield(.usage(Usage(inputTokens: promptTokens.count, outputTokens: outputCount)))
        continuation.yield(.done)
        continuation.finish()
    }
    #endif

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

                #if canImport(llama)
                await self.runLlamaInference(promptTokens: promptTokens, request: request, continuation: continuation)
                #else
                let sampleResponse = "Model running locally. System ready."
                continuation.yield(.textDelta(sampleResponse))
                continuation.yield(.usage(Usage(inputTokens: promptTokens.count, outputTokens: 8)))
                continuation.yield(.done)
                continuation.finish()
                #endif
            }
        }
    }
}
