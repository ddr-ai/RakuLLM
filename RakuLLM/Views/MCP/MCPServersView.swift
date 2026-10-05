import SwiftUI

public struct MCPServersView: View {
    @ObservedObject public var registry: MCPRegistry
    @State private var showingAddServer: Bool = false
    @State private var showingImport: Bool = false
    @State private var connectingServerID: String? = nil

    public init(registry: MCPRegistry) {
        self.registry = registry
    }

    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Registered Remote Servers").foregroundColor(RakuTheme.Color.subtle)) {
                    if registry.servers.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Text("No MCP servers configured.")
                                .font(RakuTheme.Font.body())
                                .foregroundColor(RakuTheme.Color.muted)
                            Text("Add a remote Streamable HTTP server or import an mcp.json configuration.")
                                .font(RakuTheme.Font.footnote())
                                .foregroundColor(RakuTheme.Color.subtle)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(RakuTheme.Color.elevated)
                    } else {
                        ForEach(registry.servers) { server in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(server.name)
                                            .font(RakuTheme.Font.headline())
                                            .foregroundColor(RakuTheme.Color.fg)
                                        Text(server.url)
                                            .font(RakuTheme.Font.footnote())
                                            .foregroundColor(RakuTheme.Color.subtle)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { server.enabled },
                                        set: { val in
                                            var updated = server
                                            updated.enabled = val
                                            registry.addServer(updated)
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(RakuTheme.Color.ok)
                                }

                                HStack {
                                    Picker("Mode", selection: Binding(
                                        get: { server.mode },
                                        set: { newMode in
                                            var updated = server
                                            updated.mode = newMode
                                            registry.addServer(updated)
                                        }
                                    )) {
                                        ForEach(ToolPermissionMode.allCases) { mode in
                                            if mode != .inherit {
                                                Text(mode.displayName).tag(mode)
                                            }
                                        }
                                    }
                                    .pickerStyle(.segmented)

                                    Button(action: {
                                        testConnect(server: server)
                                    }) {
                                        if connectingServerID == server.id {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Text("Connect")
                                                .font(RakuTheme.Font.footnote())
                                                .foregroundColor(RakuTheme.Color.accent)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(RakuTheme.Color.canvas)
                                                .cornerRadius(6)
                                        }
                                    }
                                }

                                if let err = server.lastError {
                                    Text(err)
                                        .font(RakuTheme.Font.footnote())
                                        .foregroundColor(RakuTheme.Color.danger)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(RakuTheme.Color.elevated)
                        }
                        .onDelete(perform: deleteServer)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
            .navigationTitle("MCP Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddServer = true }) {
                            Label("Add Server Manually", systemImage: "plus")
                        }
                        Button(action: { showingImport = true }) {
                            Label("Import mcp.json", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(RakuTheme.Color.fg)
                    }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                MCPAddServerSheet(registry: registry)
            }
            .sheet(isPresented: $showingImport) {
                MCPConfigImportSheet(registry: registry)
            }
        }
    }

    private func testConnect(server: MCPServerRecord) {
        connectingServerID = server.id
        Task {
            if let client = registry.getClient(serverID: server.id) {
                do {
                    _ = try await client.connect()
                    var updated = server
                    updated.lastConnectedAt = Date()
                    updated.lastError = nil
                    DispatchQueue.main.async {
                        registry.addServer(updated)
                        connectingServerID = nil
                    }
                } catch {
                    var updated = server
                    updated.lastError = error.localizedDescription
                    DispatchQueue.main.async {
                        registry.addServer(updated)
                        connectingServerID = nil
                    }
                }
            } else {
                connectingServerID = nil
            }
        }
    }

    private func deleteServer(at offsets: IndexSet) {
        for idx in offsets {
            let s = registry.servers[idx]
            registry.removeServer(id: s.id)
        }
    }
}
