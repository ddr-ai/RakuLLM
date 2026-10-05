import SwiftUI

public struct MCPAddServerSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject public var registry: MCPRegistry

    @State private var name: String = ""
    @State private var urlString: String = "http://"
    @State private var bearerToken: String = ""
    @State private var permissionMode: ToolPermissionMode = .allowAll

    public init(registry: MCPRegistry) {
        self.registry = registry
    }

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Details").foregroundColor(RakuTheme.Color.subtle)) {
                    TextField("Server Name (e.g. Postgres MCP)", text: $name)
                        .foregroundColor(RakuTheme.Color.fg)
                    TextField("Streamable HTTP URL", text: $urlString)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .foregroundColor(RakuTheme.Color.fg)
                }
                .listRowBackground(RakuTheme.Color.elevated)

                Section(header: Text("Authentication").foregroundColor(RakuTheme.Color.subtle), footer: Text("D3: MCP auth is a per-server bearer token stored securely in Keychain.").foregroundColor(RakuTheme.Color.subtle)) {
                    SecureField("Bearer Token (optional)", text: $bearerToken)
                        .foregroundColor(RakuTheme.Color.fg)
                }
                .listRowBackground(RakuTheme.Color.elevated)

                Section(header: Text("Default Permission Mode").foregroundColor(RakuTheme.Color.subtle)) {
                    Picker("Permission Mode", selection: $permissionMode) {
                        ForEach(ToolPermissionMode.allCases) { mode in
                            if mode != .inherit {
                                Text(mode.displayName).tag(mode)
                            }
                        }
                    }
                }
                .listRowBackground(RakuTheme.Color.elevated)
            }
            .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
            .scrollContentBackground(.hidden)
            .navigationTitle("Add MCP Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(RakuTheme.Color.muted)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveServer()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundColor(RakuTheme.Color.ok)
                }
            }
        }
    }

    private func saveServer() {
        let server = MCPServerRecord(
            name: name.trimmingCharacters(in: .whitespaces),
            url: urlString.trimmingCharacters(in: .whitespaces),
            transport: "http",
            mode: permissionMode,
            enabled: true
        )
        registry.addServer(server, token: bearerToken.isEmpty ? nil : bearerToken)
        presentationMode.wrappedValue.dismiss()
    }
}
