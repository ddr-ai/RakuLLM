import SwiftUI
import SwiftData

public struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \Message.sequence, order: .forward) private var allMessages: [Message]

    @ObservedObject public var orchestrator: ChatOrchestrator
    @ObservedObject public var mcpRegistry: MCPRegistry
    @State private var activeConversation: Conversation? = nil
    @State private var inputText: String = ""
    @State private var showingToolApproval: Bool = false
    @State private var pendingToolCall: (server: MCPServerRecord, tool: ChatToolDefinition, argsJSON: String)? = nil
    @State private var isThinkingExpanded: Bool = false

    public init(orchestrator: ChatOrchestrator, mcpRegistry: MCPRegistry) {
        self.orchestrator = orchestrator
        self.mcpRegistry = mcpRegistry
    }

    private var currentMessages: [Message] {
        guard let conv = activeConversation else { return [] }
        return allMessages.filter { $0.conversationID == conv.id }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let conv = activeConversation {
                    // Chat Transcript
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(currentMessages) { msg in
                                    ChatMessageCell(
                                        message: msg,
                                        onEdit: {
                                            inputText = msg.activeText
                                            truncateHistory(from: msg)
                                        },
                                        onRegenerate: {
                                            regenerate(message: msg)
                                        },
                                        onFork: {
                                            forkConversation(upTo: msg)
                                        },
                                        onSelectVariant: { newIdx in
                                            msg.activeVariant = newIdx
                                            try? modelContext.save()
                                        }
                                    )
                                    .id(msg.id)
                                }

                                // Streaming Assistant Preview
                                if orchestrator.isGenerating {
                                    VStack(alignment: .leading, spacing: 6) {
                                        if !orchestrator.currentThinkingText.isEmpty {
                                            DisclosureGroup("Reasoning Thought", isExpanded: $isThinkingExpanded) {
                                                Text(orchestrator.currentThinkingText)
                                                    .font(RakuTheme.Font.footnote())
                                                    .foregroundColor(RakuTheme.Color.subtle)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(8)
                                                    .background(RakuTheme.Color.canvas)
                                                    .cornerRadius(6)
                                            }
                                            .accentColor(RakuTheme.Color.subtle)
                                            .padding(.horizontal, 16)
                                        }

                                        HStack {
                                            Text(orchestrator.currentStreamingText.isEmpty ? "Thinking..." : orchestrator.currentStreamingText)
                                                .font(RakuTheme.Font.body())
                                                .foregroundColor(RakuTheme.Color.fg)
                                                .padding(12)
                                                .background(RakuTheme.Color.elevated)
                                                .cornerRadius(12)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                    }
                                    .id("streaming-indicator")
                                }

                                if let err = orchestrator.errorText {
                                    StatusBannerView(
                                        icon: "exclamationmark.triangle.fill",
                                        message: err,
                                        color: RakuTheme.Color.danger
                                    )
                                    .padding(.horizontal, 12)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .onChange(of: currentMessages.count) { _ in
                            if let last = currentMessages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: orchestrator.currentStreamingText) { _ in
                            proxy.scrollTo("streaming-indicator", anchor: .bottom)
                        }
                    }

                    // Composer
                    ChatComposerView(
                        text: $inputText,
                        isGenerating: orchestrator.isGenerating,
                        permissionMode: Binding(
                            get: { conv.toolPermissionOverride },
                            set: { conv.toolPermissionOverride = $0; try? modelContext.save() }
                        ),
                        serverCount: mcpRegistry.servers.count,
                        toolCount: ToolCatalog.shared.allEnabledTools(enabledServerIDs: Set(mcpRegistry.servers.filter { $0.enabled }.map { $0.id })).count,
                        onSend: { sendMessage() },
                        onStop: { orchestrator.cancel() }
                    )
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(RakuTheme.Color.muted)
                        Text("No Active Chat")
                            .font(RakuTheme.Font.title())
                            .foregroundColor(RakuTheme.Color.fg)
                        Button(action: startNewChat) {
                            Text("Start New Conversation")
                                .font(RakuTheme.Font.headline())
                                .foregroundColor(RakuTheme.Color.bg)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(RakuTheme.Color.ok)
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
            .navigationTitle(activeConversation?.title ?? "RakuLLM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(conversations) { conv in
                            Button(action: { activeConversation = conv }) {
                                HStack {
                                    Text(conv.title)
                                    if conv.id == activeConversation?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                        Button(action: startNewChat) {
                            Label("New Chat", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(RakuTheme.Color.fg)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(ProviderKind.allCases) { pk in
                            Button(action: {
                                activeConversation?.providerKind = pk
                                activeConversation?.modelIdentifier = pk.defaultModel
                                try? modelContext.save()
                            }) {
                                Text("\(pk.displayName) (\(pk.defaultModel))")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(activeConversation?.modelIdentifier ?? "")
                                .font(RakuTheme.Font.footnote())
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(RakuTheme.Color.muted)
                    }
                }
            }
            .onAppear {
                if activeConversation == nil {
                    if let first = conversations.first {
                        activeConversation = first
                    } else {
                        startNewChat()
                    }
                }
            }
            .sheet(isPresented: $showingToolApproval) {
                if let call = pendingToolCall {
                    ToolCallSheet(
                        serverName: call.server.name,
                        toolName: call.tool.name,
                        argumentsJSON: call.argsJSON,
                        onApprove: { _ in
                            showingToolApproval = false
                        },
                        onDeny: {
                            showingToolApproval = false
                        }
                    )
                }
            }
        }
    }

    private func startNewChat() {
        let newConv = Conversation(
            title: "New Chat",
            providerKind: .gemini,
            modelIdentifier: "gemini-2.5-flash"
        )
        modelContext.insert(newConv)
        try? modelContext.save()
        activeConversation = newConv
    }

    private func sendMessage() {
        guard let conv = activeConversation else { return }
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        let userMsg = Message(
            conversationID: conv.id,
            sequence: currentMessages.count,
            role: .user,
            text: prompt
        )
        modelContext.insert(userMsg)
        conv.updatedAt = Date()
        if conv.title == "New Chat" {
            conv.title = String(prompt.prefix(28))
        }
        try? modelContext.save()

        runInference(conv: conv, prompt: prompt)
    }

    private func runInference(conv: Conversation, prompt: String) {
        let provider = providerFor(kind: conv.providerKind)
        let key = KeychainHelper.load(key: conv.providerKind.keychainKey) ?? ""

        let enabledServers = mcpRegistry.servers.filter { $0.enabled }
        let tools = ToolCatalog.shared.allEnabledTools(enabledServerIDs: Set(enabledServers.map { $0.id }))

        orchestrator.send(
            conversation: conv,
            history: currentMessages,
            userPrompt: prompt,
            provider: provider,
            apiKey: key,
            tools: tools.isEmpty ? nil : tools
        ) { updatedAssistantMessage in
            if !self.currentMessages.contains(where: { $0.id == updatedAssistantMessage.id }) {
                self.modelContext.insert(updatedAssistantMessage)
            }
            try? self.modelContext.save()
        }
    }

    private func truncateHistory(from msg: Message) {
        let msgsToDelete = currentMessages.filter { $0.sequence >= msg.sequence }
        for m in msgsToDelete {
            modelContext.delete(m)
        }
        try? modelContext.save()
    }

    private func regenerate(message: Message) {
        guard let conv = activeConversation else { return }
        let previousUserPrompt = currentMessages.last(where: { $0.role == .user })?.activeText ?? ""
        runInference(conv: conv, prompt: previousUserPrompt)
    }

    private func forkConversation(upTo msg: Message) {
        guard let conv = activeConversation else { return }
        let forked = Conversation(
            title: "Fork: \(conv.title)",
            providerKind: conv.providerKind,
            modelIdentifier: conv.modelIdentifier,
            forkedFromID: conv.id,
            forkedAtMessageID: msg.id
        )
        modelContext.insert(forked)

        let upToMessages = currentMessages.filter { $0.sequence <= msg.sequence }
        for m in upToMessages {
            let copy = Message(
                conversationID: forked.id,
                sequence: m.sequence,
                role: m.role,
                text: m.activeText
            )
            modelContext.insert(copy)
        }
        try? modelContext.save()
        activeConversation = forked
    }

    private func providerFor(kind: ProviderKind) -> LLMProvider {
        switch kind {
        case .gemini: return GeminiProvider()
        case .openai: return OpenAIProvider()
        case .grok: return GrokProvider()
        case .anthropic: return AnthropicProvider()
        case .local: return GeminiProvider() // local bridged through engine
        }
    }
}
