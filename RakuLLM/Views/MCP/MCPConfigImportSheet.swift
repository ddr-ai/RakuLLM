import SwiftUI

public struct MCPConfigImportSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject public var registry: MCPRegistry

    @State private var jsonText: String = ""
    @State private var parseResult: MCPImportResult? = nil
    @State private var errorMessage: String? = nil

    public init(registry: MCPRegistry) {
        self.registry = registry
    }

    public var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste contents of mcp.json below:")
                    .font(RakuTheme.Font.subheadline())
                    .foregroundColor(RakuTheme.Color.subtle)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                TextEditor(text: $jsonText)
                    .font(RakuTheme.Font.code(size: 12))
                    .foregroundColor(RakuTheme.Color.fg)
                    .padding(8)
                    .background(RakuTheme.Color.canvas)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(RakuTheme.Color.line))
                    .frame(height: 180)
                    .padding(.horizontal, 16)

                Button(action: parseJSON) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Parse Configuration")
                    }
                    .font(RakuTheme.Font.headline())
                    .foregroundColor(RakuTheme.Color.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RakuTheme.Color.accent)
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                }

                if let err = errorMessage {
                    StatusBannerView(
                        icon: "exclamationmark.triangle.fill",
                        message: err,
                        color: RakuTheme.Color.danger
                    )
                    .padding(.horizontal, 16)
                }

                if let result = parseResult {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if !result.importedServers.isEmpty {
                                Text("VALID SERVERS (\(result.importedServers.count))")
                                    .font(RakuTheme.Font.footnote())
                                    .foregroundColor(RakuTheme.Color.ok)

                                ForEach(result.importedServers) { s in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.name)
                                            .font(RakuTheme.Font.headline())
                                            .foregroundColor(RakuTheme.Color.fg)
                                        Text(s.url)
                                            .font(RakuTheme.Font.footnote())
                                            .foregroundColor(RakuTheme.Color.subtle)
                                    }
                                    .rakuCard()
                                }
                            }

                            if !result.unsupportedEntries.isEmpty {
                                Text("UNSUPPORTED ENTRIES (\(result.unsupportedEntries.count))")
                                    .font(RakuTheme.Font.footnote())
                                    .foregroundColor(RakuTheme.Color.warning)

                                ForEach(result.unsupportedEntries, id: \.serverName) { u in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(u.serverName)
                                            .font(RakuTheme.Font.headline())
                                            .foregroundColor(RakuTheme.Color.fg)
                                        Text("Command: \(u.command)")
                                            .font(RakuTheme.Font.code(size: 11))
                                            .foregroundColor(RakuTheme.Color.subtle)
                                        Text(u.reason)
                                            .font(RakuTheme.Font.footnote())
                                            .foregroundColor(RakuTheme.Color.warning)
                                    }
                                    .rakuCard()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !result.importedServers.isEmpty {
                        Button(action: applyImport) {
                            Text("Import \(result.importedServers.count) Server(s)")
                                .font(RakuTheme.Font.headline())
                                .foregroundColor(RakuTheme.Color.bg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RakuTheme.Color.ok)
                                .cornerRadius(10)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                        }
                    }
                }

                Spacer()
            }
            .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
            .navigationTitle("Import mcp.json")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(RakuTheme.Color.muted)
                }
            }
        }
    }

    private func parseJSON() {
        errorMessage = nil
        do {
            let res = try MCPConfigImporter.shared.parseConfig(jsonString: jsonText)
            self.parseResult = res
        } catch {
            self.errorMessage = "Failed to parse JSON: \(error.localizedDescription)"
        }
    }

    private func applyImport() {
        guard let res = parseResult else { return }
        for s in res.importedServers {
            registry.addServer(s)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
