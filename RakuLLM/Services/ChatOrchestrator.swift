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
        tools: [ChatToolDefinition]? = nil,
        onUpdateMessage: @escaping (Message) -> Void
    ) {
        cancel()
        isGenerating = true
        errorText = nil
        currentStreamingText = ""
        currentThinkingText = ""

        let startTime = Date()
        var firstTokenTime: Date? = nil

        // Build request messages
        var requestMessages: [ChatRequestMessage] = []
        for msg in history {
            requestMessages.append(ChatRequestMessage(role: msg.role.rawValue, content: msg.activeText))
        }
        requestMessages.append(ChatRequestMessage(role: "user", content: userPrompt))

        // Determine context budget (T2, T3, T4)
        let nCtx = 8192
        let budget = TokenMeter.shared.computeBudget(nCtx: nCtx, requestedMaxOutputTokens: 2048)
        let windowed = TokenMeter.shared.windowMessages(
            messages: requestMessages,
            systemPrompt: conversation.systemPromptOverride,
            budget: budget
        )

        let promptTokensEst = TokenMeter.shared.estimateTokens(for: userPrompt) + windowed.totalTokensUsed
        let maxTokens = TokenMeter.shared.computeMaxOutputTokens(nCtx: nCtx, promptTokens: promptTokensEst)

        let request = ChatRequest(
            model: conversation.modelIdentifier,
            messages: windowed.includedMessages,
            systemPrompt: conversation.systemPromptOverride,
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

        activeStreamTask = Task {
            do {
                let stream = provider.stream(request: request, apiKey: apiKey)
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

                    case .toolCall(let name, let args, let callId):
                        // Record tool invocation
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

                assistantMessage.costUSD = CostTable.shared.calculateCost(
                    model: conversation.modelIdentifier,
                    inputTokens: assistantMessage.tokensIn,
                    outputTokens: assistantMessage.tokensOut
                )

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
