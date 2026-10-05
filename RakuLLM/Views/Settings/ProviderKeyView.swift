import SwiftUI

public struct ProviderKeyView: View {
    public let provider: ProviderKind
    @State private var apiKey: String = ""
    @State private var isSaved: Bool = false

    public init(provider: ProviderKind) {
        self.provider = provider
    }

    public var body: some View {
        Form {
            Section(header: Text("\(provider.displayName) API Key").foregroundColor(RakuTheme.Color.subtle), footer: Text("Keys are securely stored in the iOS Keychain and never backed up to iCloud.").foregroundColor(RakuTheme.Color.subtle)) {
                SecureField("Enter API Key", text: $apiKey)
                    .foregroundColor(RakuTheme.Color.fg)

                Button(action: saveKey) {
                    HStack {
                        Spacer()
                        Text(isSaved ? "Saved to Keychain" : "Save Key")
                            .font(RakuTheme.Font.headline())
                            .foregroundColor(isSaved ? RakuTheme.Color.ok : RakuTheme.Color.bg)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(isSaved ? RakuTheme.Color.elevated : RakuTheme.Color.ok)
                    .cornerRadius(8)
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                if isConfigured {
                    Button("Remove Key", role: .destructive) {
                        _ = KeychainHelper.delete(key: provider.keychainKey)
                        apiKey = ""
                        isSaved = false
                    }
                    .foregroundColor(RakuTheme.Color.danger)
                }
            }
            .listRowBackground(RakuTheme.Color.elevated)
        }
        .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
        .scrollContentBackground(.hidden)
        .navigationTitle(provider.displayName)
        .onAppear {
            if let saved = KeychainHelper.load(key: provider.keychainKey) {
                apiKey = saved
            }
        }
    }

    private var isConfigured: Bool {
        KeychainHelper.load(key: provider.keychainKey) != nil
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if KeychainHelper.save(key: provider.keychainKey, secret: trimmed) {
            isSaved = true
        }
    }
}
