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

    // Web Search & Production Code toggles
    @State private var isWebSearchEnabled: Bool = false
    @State private var isProductionCodeEnabled: Bool = false

    // Chat Rename & Delete state
    @State private var showingRenameAlert: Bool = false
    @State private var renameTitleText: String = ""
    @State private var showingDeleteConfirmation: Bool = false

    public init(orchestrator: ChatOrchestrator, mcpRegistry: MCPRegistry) {
        self.orchestrator = orchestrator
        self.mcpRegistry = mcpRegistry
    }

    private var currentMessages: [Message] {
        guard let conv = activeConversation else { return [] }
        return allMessages.filter { $0.conversationID == conv.id }
    }

    private var localGGUFModels: [ModelRecord] {
        let dir = DownloadManager.shared.modelsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return [] }
        return files.filter {
            $0.pathExtension.lowercased() == "gguf" &&
            !$0.lastPathComponent.lowercased().contains("mmproj")
        }.map { file in
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return ModelRecord(
                repo: "local",
                filename: file.lastPathComponent,
                localPath: file.path,
                fileSizeBytes: Int64(size),
                downloadState: .completed
            )
        }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let conv = activeConversation {
                    // Chat Transcript
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                if currentMessages.isEmpty && !orchestrator.isGenerating {
                                    CleanEmptyChatView(
                                        modelName: conv.modelIdentifier,
                                        isLocal: conv.providerKind == .local,
                                        onSelectPrompt: { suggestion in
                                            inputText = suggestion
                                        }
                                    )
                                    .padding(.top, 32)
                                    .padding(.horizontal, 16)
                                } else {
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
                                }

                                // Streaming Assistant Preview with Code Formatting
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

                                        FormattedMessageView(
                                            text: orchestrator.currentStreamingText.isEmpty ? "Thinking..." : orchestrator.currentStreamingText,
                                            isUser: false
                                        )
                                        .padding(12)
                                        .background(RakuTheme.Color.elevated)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(RakuTheme.Color.line, lineWidth: 1)
                                        )
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
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: currentMessages.count) { _ in
                            if let last = currentMessages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: orchestrator.currentStreamingText) { _ in
                            proxy.scrollTo("streaming-indicator", anchor: .bottom)
                        }
                    }

                    // Composer with Web Search and Production Code options
                    ChatComposerView(
                        text: $inputText,
                        isGenerating: orchestrator.isGenerating,
                        permissionMode: Binding(
                            get: { conv.toolPermissionOverride },
                            set: { conv.toolPermissionOverride = $0; try? modelContext.save() }
                        ),
                        isWebSearchEnabled: $isWebSearchEnabled,
                        isProductionCodeEnabled: $isProductionCodeEnabled,
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
            // Swipe down anywhere on phone screen to dismiss keyboard
            .gesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .local)
                    .onChanged { gesture in
                        if gesture.translation.height > 20 && abs(gesture.translation.width) < 80 {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
            )
            .navigationTitle(activeConversation?.title ?? "RakuLLM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Leading: Conversation management (Switch, Rename, Delete, New Chat)
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        if let conv = activeConversation {
                            Button(action: {
                                renameTitleText = conv.title
                                showingRenameAlert = true
                            }) {
                                Label("Rename Chat", systemImage: "pencil")
                            }

                            Button(role: .destructive, action: {
                                showingDeleteConfirmation = true
                            }) {
                                Label("Delete Chat", systemImage: "trash")
                            }

                            Divider()
                        }

                        Button(action: startNewChat) {
                            Label("New Chat", systemImage: "plus")
                        }

                        if !conversations.isEmpty {
                            Divider()
                            Section("Conversations") {
                                ForEach(conversations) { conv in
                                    Button(action: { switchConversation(to: conv) }) {
                                        HStack {
                                            Text(conv.title)
                                            if conv.id == activeConversation?.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.circle")
                            .foregroundColor(RakuTheme.Color.fg)
                    }
                }

                // Trailing: Model Picker (Local GGUF models detected from Hugging Face & Cloud Models)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Section 1: Detected On-Device GGUF Models (Free, Offline, Zero API Keys)
                        Section("On-Device Models (GGUF - Free & Offline)") {
                            if localGGUFModels.isEmpty {
                                Button(action: {}) {
                                    Label("No local models found (Download in Models tab)", systemImage: "arrow.down.circle")
                                }
                                .disabled(true)
                            } else {
                                ForEach(localGGUFModels) { model in
                                    Button(action: {
                                        activeConversation?.providerKind = .local
                                        activeConversation?.modelIdentifier = model.filename
                                        try? modelContext.save()
                                    }) {
                                        HStack {
                                            Text(model.filename)
                                            if activeConversation?.providerKind == .local && activeConversation?.modelIdentifier == model.filename {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Section 2: Optional Cloud Providers (Gemini, OpenAI, Grok, Anthropic)
                        Section("Cloud Models (Optional)") {
                            ForEach([ProviderKind.gemini, .openai, .grok, .anthropic]) { pk in
                                let hasKey = KeychainHelper.load(key: pk.keychainKey) != nil
                                Button(action: {
                                    activeConversation?.providerKind = pk
                                    activeConversation?.modelIdentifier = pk.defaultModel
                                    try? modelContext.save()
                                }) {
                                    HStack {
                                        Text("\(pk.displayName) (\(pk.defaultModel))\(hasKey ? "" : " - Key Needed")")
                                        if activeConversation?.providerKind == pk {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: activeConversation?.providerKind == .local ? "cpu" : "cloud")
                                .font(.system(size: 10))
                                .foregroundColor(activeConversation?.providerKind == .local ? RakuTheme.Color.accent : RakuTheme.Color.ok)
                            Text(activeConversation?.modelIdentifier ?? "Model")
                                .font(RakuTheme.Font.footnote())
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(RakuTheme.Color.fg)
                    }
                }
            }
            .alert("Rename Chat", isPresented: $showingRenameAlert) {
                TextField("Chat Title", text: $renameTitleText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    let trimmed = renameTitleText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, let conv = activeConversation {
                        conv.title = trimmed
                        try? modelContext.save()
                    }
                }
            } message: {
                Text("Enter a new title for this conversation.")
            }
            .alert("Delete Chat?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteCurrentConversation()
                }
            } message: {
                Text("Are you sure you want to delete '\(activeConversation?.title ?? "this chat")'? All messages will be permanently removed.")
            }
            .onAppear {
                if activeConversation == nil {
                    if let first = conversations.first {
                        activeConversation = first
                    } else {
                        startNewChat()
                    }
                }

                // Auto-repair conversation if it points to a multimodal projector file (mmproj)
                if let conv = activeConversation, conv.modelIdentifier.lowercased().contains("mmproj") {
                    if let valid = localGGUFModels.first {
                        conv.modelIdentifier = valid.filename
                        conv.providerKind = .local
                    } else {
                        conv.providerKind = .gemini
                        conv.modelIdentifier = ProviderKind.gemini.defaultModel
                    }
                    try? modelContext.save()
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

    private func switchConversation(to conv: Conversation) {
        orchestrator.resetState()
        inputText = ""
        if conv.modelIdentifier.lowercased().contains("mmproj") {
            if let valid = localGGUFModels.first {
                conv.modelIdentifier = valid.filename
                conv.providerKind = .local
            } else {
                conv.providerKind = .gemini
                conv.modelIdentifier = ProviderKind.gemini.defaultModel
            }
            try? modelContext.save()
        }
        activeConversation = conv
    }

    private func startNewChat() {
        orchestrator.resetState()
        inputText = ""
        isWebSearchEnabled = false
        isProductionCodeEnabled = false

        let local = localGGUFModels.first
        let pk: ProviderKind = local != nil ? .local : .gemini
        let modelId = local?.filename ?? ProviderKind.gemini.defaultModel
        let newConv = Conversation(
            title: "New Chat",
            providerKind: pk,
            modelIdentifier: modelId
        )
        modelContext.insert(newConv)
        try? modelContext.save()
        activeConversation = newConv
    }

    private func deleteCurrentConversation() {
        guard let conv = activeConversation else { return }
        orchestrator.resetState()
        inputText = ""
        let msgs = allMessages.filter { $0.conversationID == conv.id }
        for m in msgs {
            modelContext.delete(m)
        }
        modelContext.delete(conv)
        try? modelContext.save()
        activeConversation = conversations.first(where: { $0.id != conv.id })
        if activeConversation == nil {
            startNewChat()
        }
    }

    private func sendMessage() {
        guard var conv = activeConversation else { return }
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        // Automatic Chat Rollover with Memory if approaching token limit
        conv = checkAndPerformRolloverIfNeeded(conv: conv, nextPrompt: prompt)

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

    private func checkAndPerformRolloverIfNeeded(conv: Conversation, nextPrompt: String) -> Conversation {
        let estTokens = currentMessages.reduce(0) { $0 + TokenMeter.shared.estimateTokens(for: $1.activeText) } + TokenMeter.shared.estimateTokens(for: nextPrompt)
        let maxLimit = (conv.providerKind == .local) ? 4096 : 8192

        if estTokens >= Int(Double(maxLimit) * 0.85) && !currentMessages.isEmpty {
            let memorySummary = buildMemorySummary(messages: currentMessages, title: conv.title)

            let continuedConv = Conversation(
                title: "\(conv.title) (Continued)",
                providerKind: conv.providerKind,
                modelIdentifier: conv.modelIdentifier,
                systemPromptOverride: (conv.systemPromptOverride != nil ? conv.systemPromptOverride! + "\n\n" : "") + "[CONVERSATION MEMORY CARRYOVER]\n" + memorySummary
            )
            modelContext.insert(continuedConv)

            let rolloverNotice = Message(
                conversationID: continuedConv.id,
                sequence: 0,
                role: .assistant,
                text: "⚡ *Context token limit reached. Automatically transitioned to a continuation chat with conversation memory preserved.*"
            )
            modelContext.insert(rolloverNotice)
            try? modelContext.save()

            self.activeConversation = continuedConv
            return continuedConv
        }
        return conv
    }

    private func buildMemorySummary(messages: [Message], title: String) -> String {
        var summary = "Summary of previous conversation context from '\(title)':\n"
        let keyMsgs = messages.suffix(8)
        for m in keyMsgs {
            let snippet = m.activeText.prefix(120).replacingOccurrences(of: "\n", with: " ")
            summary += "- [\(m.role.rawValue.capitalized)]: \(snippet)...\n"
        }
        return summary
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
            isWebSearchEnabled: isWebSearchEnabled,
            isProductionCodeEnabled: isProductionCodeEnabled,
            tools: tools.isEmpty ? nil : tools,
            onApproachingTokenLimit: { [weak conv] in
                // Notification callback if needed
            },
            onUpdateMessage: { updatedAssistantMessage in
                if !self.currentMessages.contains(where: { $0.id == updatedAssistantMessage.id }) {
                    self.modelContext.insert(updatedAssistantMessage)
                }
                try? self.modelContext.save()
            }
        )
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
        case .local: return GeminiProvider() // local bridged through LlamaEngine
        }
    }
}

private struct CleanEmptyChatView: View {
    let modelName: String
    let isLocal: Bool
    let onSelectPrompt: (String) -> Void

    private let suggestions = [
        "Explain quantum computing in simple terms",
        "Write a robust Swift actor for caching images",
        "How do transformers and attention mechanisms work?",
        "Help me brainstorm architectural designs for my app"
    ]

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(RakuTheme.Color.accent.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: isLocal ? "cpu" : "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(RakuTheme.Color.accent)
            }

            VStack(spacing: 6) {
                Text("How can I help you today?")
                    .font(RakuTheme.Font.title())
                    .foregroundColor(RakuTheme.Color.fg)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    Circle()
                        .fill(isLocal ? RakuTheme.Color.ok : RakuTheme.Color.accent)
                        .frame(width: 6, height: 6)
                    Text(isLocal ? "On-Device GGUF • Private & Offline" : "Cloud Model • \(modelName)")
                        .font(RakuTheme.Font.footnote())
                        .foregroundColor(RakuTheme.Color.subtle)
                }
            }

            VStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { prompt in
                    Button(action: {
                        onSelectPrompt(prompt)
                    }) {
                        HStack {
                            Text(prompt)
                                .font(RakuTheme.Font.subheadline())
                                .foregroundColor(RakuTheme.Color.fg)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundColor(RakuTheme.Color.subtle)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(RakuTheme.Color.elevated)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(RakuTheme.Color.line, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }
}
