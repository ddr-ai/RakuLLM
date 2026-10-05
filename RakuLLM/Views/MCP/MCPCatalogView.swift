import SwiftUI

public struct MCPCatalogView: View {
    @ObservedObject public var registry: MCPRegistry
    @State private var selectedCategory: ToolCategory = .all
    @State private var searchText: String = ""
    @State private var selectedToolForAuth: DirectoryToolItem? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
    ]

    public init(registry: MCPRegistry) {
        self.registry = registry
    }

    private var filteredTools: [DirectoryToolItem] {
        PublicMCPDirectory.shared.search(query: searchText, category: selectedCategory)
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(RakuTheme.Color.muted)
                TextField("Search hundreds of tools & services...", text: $searchText)
                    .font(RakuTheme.Font.body())
                    .foregroundColor(RakuTheme.Color.fg)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(RakuTheme.Color.muted)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RakuTheme.Color.canvas)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(RakuTheme.Color.line, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 4)

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ToolCategory.allCases) { cat in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = cat
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 11))
                                Text(cat.rawValue)
                                    .font(RakuTheme.Font.footnote())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedCategory == cat ? RakuTheme.Color.accent : RakuTheme.Color.elevated)
                            .foregroundColor(selectedCategory == cat ? RakuTheme.Color.bg : RakuTheme.Color.fg)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedCategory == cat ? Color.clear : RakuTheme.Color.line, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            // Grid Layer of Tools & Services
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredTools) { tool in
                        let isConnected = registry.servers.contains(where: { $0.id == tool.id })
                        ToolGridCard(
                            tool: tool,
                            isConnected: isConnected,
                            onConnectToggle: {
                                toggleConnect(tool: tool, isConnected: isConnected)
                            },
                            onManualAuth: {
                                selectedToolForAuth = tool
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .sheet(item: $selectedToolForAuth) { tool in
            ManualToolAuthSheet(tool: tool, registry: registry)
        }
    }

    private func toggleConnect(tool: DirectoryToolItem, isConnected: Bool) {
        if isConnected {
            registry.removeServer(id: tool.id)
        } else {
            let record = MCPServerRecord(
                id: tool.id,
                name: tool.name,
                url: tool.defaultURL,
                mode: .confirmEach,
                enabled: true
            )
            registry.addServer(record)
        }
    }
}

public struct ToolGridCard: View {
    public let tool: DirectoryToolItem
    public let isConnected: Bool
    public let onConnectToggle: () -> Void
    public let onManualAuth: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon & Auth button
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isConnected ? RakuTheme.Color.ok.opacity(0.15) : RakuTheme.Color.canvas)
                        .frame(width: 32, height: 32)
                    Image(systemName: tool.icon)
                        .font(.system(size: 15))
                        .foregroundColor(isConnected ? RakuTheme.Color.ok : RakuTheme.Color.accent)
                }

                Spacer()

                Button(action: onManualAuth) {
                    Image(systemName: tool.requiresAuth ? "lock.fill" : "slider.horizontal.3")
                        .font(.system(size: 11))
                        .foregroundColor(tool.requiresAuth ? RakuTheme.Color.warning : RakuTheme.Color.subtle)
                        .padding(5)
                        .background(RakuTheme.Color.canvas)
                        .clipShape(Circle())
                }
            }

            // Name
            Text(tool.name)
                .font(RakuTheme.Font.headline())
                .foregroundColor(RakuTheme.Color.fg)
                .lineLimit(1)

            // Category tag
            Text(tool.category.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(RakuTheme.Color.subtle)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RakuTheme.Color.canvas)
                .cornerRadius(4)

            // Description
            Text(tool.description)
                .font(RakuTheme.Font.footnote())
                .foregroundColor(RakuTheme.Color.muted)
                .lineLimit(3)
                .frame(maxHeight: 45, alignment: .topLeading)

            Spacer(minLength: 4)

            // Connect Button
            Button(action: onConnectToggle) {
                HStack(spacing: 4) {
                    Image(systemName: isConnected ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 11))
                    Text(isConnected ? "Connected" : "Connect")
                        .font(RakuTheme.Font.footnote())
                        .fontWeight(.semibold)
                }
                .foregroundColor(isConnected ? RakuTheme.Color.ok : RakuTheme.Color.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isConnected ? RakuTheme.Color.canvas : RakuTheme.Color.ok)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isConnected ? RakuTheme.Color.ok.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(RakuTheme.Color.elevated)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isConnected ? RakuTheme.Color.ok.opacity(0.6) : RakuTheme.Color.line, lineWidth: 1)
        )
    }
}

public struct ManualToolAuthSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    public let tool: DirectoryToolItem
    @ObservedObject public var registry: MCPRegistry

    @State private var serverName: String = ""
    @State private var serverURL: String = ""
    @State private var authToken: String = ""
    @State private var isEnabled: Bool = true
    @State private var mode: ToolPermissionMode = .confirmEach

    public init(tool: DirectoryToolItem, registry: MCPRegistry) {
        self.tool = tool
        self.registry = registry
        _serverName = State(initialValue: tool.name)
        _serverURL = State(initialValue: tool.defaultURL)
    }

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Service Configuration").foregroundColor(RakuTheme.Color.subtle)) {
                    HStack {
                        Text("Name")
                            .font(RakuTheme.Font.footnote())
                            .foregroundColor(RakuTheme.Color.subtle)
                            .frame(width: 80, alignment: .leading)
                        TextField("Server Name", text: $serverName)
                            .foregroundColor(RakuTheme.Color.fg)
                    }

                    HStack {
                        Text("URL")
                            .font(RakuTheme.Font.footnote())
                            .foregroundColor(RakuTheme.Color.subtle)
                            .frame(width: 80, alignment: .leading)
                        TextField("https://...", text: $serverURL)
                            .foregroundColor(RakuTheme.Color.fg)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .listRowBackground(RakuTheme.Color.elevated)

                Section(
                    header: Text("Authentication (Optional)").foregroundColor(RakuTheme.Color.subtle),
                    footer: Text("Bearer token or API key stored securely in iOS Keychain.").foregroundColor(RakuTheme.Color.subtle)
                ) {
                    SecureField("Bearer Token / API Key", text: $authToken)
                        .foregroundColor(RakuTheme.Color.fg)
                }
                .listRowBackground(RakuTheme.Color.elevated)

                Section(header: Text("Execution Policy").foregroundColor(RakuTheme.Color.subtle)) {
                    Picker("Permission", selection: $mode) {
                        ForEach([ToolPermissionMode.confirmEach, .allowAll, .allowlist]) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(RakuTheme.Color.elevated)
            }
            .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
            .scrollContentBackground(.hidden)
            .navigationTitle("Configure \(tool.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(RakuTheme.Color.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Connect") {
                        saveAndConnect()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(RakuTheme.Color.ok)
                }
            }
            .onAppear {
                if let existing = registry.servers.first(where: { $0.id == tool.id }) {
                    serverName = existing.name
                    serverURL = existing.url
                    mode = existing.mode
                    if let savedToken = KeychainHelper.load(key: existing.keychainTokenKey) {
                        authToken = savedToken
                    }
                }
            }
        }
    }

    private func saveAndConnect() {
        let record = MCPServerRecord(
            id: tool.id,
            name: serverName.isEmpty ? tool.name : serverName,
            url: serverURL.isEmpty ? tool.defaultURL : serverURL,
            mode: mode,
            enabled: true
        )
        registry.addServer(record, token: authToken.isEmpty ? nil : authToken)
    }
}
