import Foundation
import SwiftUI
import Combine

@MainActor
public final class ChatOrchestrator: ObservableObject {
    @Published public var isGenerating: Bool = false
    @Published public var currentStreamingText: String = ""
    @Published public var currentThinkingText: String = ""
    @Published public var errorText: String? = nil

    private var activeStreamTask: Task<Void, Never>? = nil

    public init() {}

    public func cancel() {
        activeStreamTask?.cancel()
        activeStreamTask = nil
        isGenerating = false
    }

    /// T5 Streaming only: Persist assistant text incrementally throttled to 500ms or 256 chars.
    public func send(
        conversation: Conversation,
        history: [Message],
        userPrompt: String,
        provider: LLMProvider,
        apiKey: String,
        isWebSearchEnabled: Bool = false,
        isProductionCodeEnabled: Bool = false,
        tools: [ChatToolDefinition]? = nil,
        onApproachingTokenLimit: (() -> Void)? = nil,
        onUpdateMessage: @escaping (Message) -> Void
    ) {
        cancel()
        isGenerating = true
        errorText = nil
        currentStreamingText = ""
        currentThinkingText = ""

        // Validate API Key for commercial providers only (local models require zero API keys)
        if conversation.providerKind != .local && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.errorText = "\(conversation.providerKind.displayName) requires an API key. Go to Settings > Cloud Providers to save your key, or select a local on-device GGUF model."
            self.isGenerating = false
            return
        }

        let startTime = Date()
        var firstTokenTime: Date? = nil

        activeStreamTask = Task {
            var promptAugmentation = ""

            // 1. Live Web Search (DuckDuckGo / Wikipedia without API key)
            if isWebSearchEnabled {
                self.currentStreamingText = "[Searching the web...]\n"
                let searchResults = await WebSearchService.shared.search(query: userPrompt)
                if !searchResults.isEmpty {
                    promptAugmentation += WebSearchService.shared.formatResultsForPrompt(query: userPrompt, results: searchResults)
                }
                self.currentStreamingText = ""
            }

            // 2. Production Code Mandate
            var systemDirective = conversation.systemPromptOverride ?? ""
            if isProductionCodeEnabled {
                systemDirective += "\n\n[PRODUCTION CODE MANDATE: Generate clean, robust, highly accurate, and production-ready code. Adhere strictly to software engineering best practices: type safety, idiomatic design patterns, comprehensive error handling, modular architecture, edge case prevention, and zero omitted or stubbed placeholders.]"
            }

            // 3. Build request messages
            var requestMessages: [ChatRequestMessage] = []
            for msg in history {
                requestMessages.append(ChatRequestMessage(role: msg.role.rawValue, content: msg.activeText))
            }

            let finalUserPrompt = promptAugmentation.isEmpty ? userPrompt : "\(userPrompt)\n\(promptAugmentation)"
            requestMessages.append(ChatRequestMessage(role: "user", content: finalUserPrompt))

            // 4. Determine context budget (T2, T3, T4)
            let nCtx = (conversation.providerKind == .local) ? 4096 : 8192
            let budget = TokenMeter.shared.computeBudget(nCtx: nCtx, requestedMaxOutputTokens: 2048)
            let windowed = TokenMeter.shared.windowMessages(
                messages: requestMessages,
                systemPrompt: systemDirective.isEmpty ? nil : systemDirective,
                budget: budget
            )

            let promptTokensEst = TokenMeter.shared.estimateTokens(for: finalUserPrompt) + windowed.totalTokensUsed
            let maxTokens = TokenMeter.shared.computeMaxOutputTokens(nCtx: nCtx, promptTokens: promptTokensEst)

            // Trigger rollover callback if approaching context limit (>= 85% capacity)
            if promptTokensEst >= Int(Double(nCtx) * 0.85) {
                onApproachingTokenLimit?()
            }

            let request = ChatRequest(
                model: conversation.modelIdentifier,
                messages: windowed.includedMessages,
                systemPrompt: systemDirective.isEmpty ? nil : systemDirective,
                maxOutputTokens: maxTokens,
                tools: tools
            )

            let assistantMessage = Message(
                conversationID: conversation.id,
                sequence: history.count + 1,
                role: .assistant,
                text: "",
                tokensIn: promptTokensEst,
                tokensOut: 0,
                isUsageEstimated: true
            )

            var lastPersistTime = Date()
            var unpersistedCharCount = 0

            do {
                // Route stream: Local LlamaEngine vs Cloud Provider
                let stream: AsyncThrowingStream<ChatEvent, Error>
                if conversation.providerKind == .local {
                    // Ensure local model weights are loaded
                    let loaded = await LlamaEngine.shared.isLoaded
                    let loadedID = await LlamaEngine.shared.loadedModelID
                    if !loaded || loadedID != conversation.modelIdentifier {
                        let modelsDir = DownloadManager.shared.modelsDirectory
                        let candidate = modelsDir.appendingPathComponent(conversation.modelIdentifier)
                        if FileManager.default.fileExists(atPath: candidate.path) {
                            try await LlamaEngine.shared.loadModel(path: candidate.path, settings: ModelSettings(modelID: conversation.modelIdentifier))
                        } else if let files = try? FileManager.default.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: nil) {
                            if let found = files.first(where: { $0.lastPathComponent == conversation.modelIdentifier || $0.lastPathComponent.contains(conversation.modelIdentifier) }) {
                                try await LlamaEngine.shared.loadModel(path: found.path, settings: ModelSettings(modelID: conversation.modelIdentifier))
                            }
                        }
                    }
                    stream = LlamaEngine.shared.generate(request: request)
                } else {
                    stream = provider.stream(request: request, apiKey: apiKey)
                }

                for try await event in stream {
                    if Task.isCancelled { break }

                    switch event {
                    case .textDelta(let delta):
                        if firstTokenTime == nil {
                            firstTokenTime = Date()
                        }
                        self.currentStreamingText.append(delta)
                        unpersistedCharCount += delta.count

                        // Throttled persistence: 500ms or 256 chars (T5)
                        let elapsed = Date().timeIntervalSince(lastPersistTime)
                        if elapsed >= 0.5 || unpersistedCharCount >= 256 {
                            assistantMessage.updateActiveText(self.currentStreamingText)
                            onUpdateMessage(assistantMessage)
                            lastPersistTime = Date()
                            unpersistedCharCount = 0
                        }

                    case .thinking(let thought):
                        self.currentThinkingText.append(thought)

                    case .usage(let usage):
                        assistantMessage.tokensIn = usage.inputTokens
                        assistantMessage.tokensOut = usage.outputTokens
                        assistantMessage.isUsageEstimated = false

                    case .toolCall(let name, _, let callId):
                        assistantMessage.toolInvocationID = "\(name)::\(callId)"
                        self.currentStreamingText.append("\n[Tool Call: \(name)]\n")

                    case .done:
                        break
                    }
                }

                // Finalize metrics
                let endTime = Date()
                let totalDurationMs = endTime.timeIntervalSince(startTime) * 1000.0
                let firstTokenMs = firstTokenTime.map { $0.timeIntervalSince(startTime) * 1000.0 } ?? totalDurationMs

                assistantMessage.updateActiveText(self.currentStreamingText)
                assistantMessage.durationMs = totalDurationMs
                assistantMessage.firstTokenMs = firstTokenMs

                if assistantMessage.tokensOut == 0 {
                    assistantMessage.tokensOut = TokenMeter.shared.estimateTokens(for: self.currentStreamingText)
                }

                if totalDurationMs > 0 && assistantMessage.tokensOut > 0 {
                    assistantMessage.ttps = Double(assistantMessage.tokensOut) / (totalDurationMs / 1000.0)
                }

                if conversation.providerKind != .local {
                    assistantMessage.costUSD = CostTable.shared.calculateCost(
                        model: conversation.modelIdentifier,
                        inputTokens: assistantMessage.tokensIn,
                        outputTokens: assistantMessage.tokensOut
                    )
                } else {
                    assistantMessage.costUSD = 0.0 // On-device local models are completely free
                }

                onUpdateMessage(assistantMessage)
                self.isGenerating = false
            } catch {
                if !Task.isCancelled {
                    self.errorText = error.localizedDescription
                }
                self.isGenerating = false
            }
        }
    }
}
