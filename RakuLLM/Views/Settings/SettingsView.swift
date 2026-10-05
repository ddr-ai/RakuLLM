import SwiftUI

public struct SettingsView: View {
    @State private var hfToken: String = ""
    @State private var missingKeyProviders: [ProviderKind] = []

    public init() {}

    public var body: some View {
        NavigationView {
            Form {
                if !missingKeyProviders.isEmpty {
                    Section {
                        ForEach(missingKeyProviders) { p in
                            StatusBannerView(
                                icon: "key.fill",
                                message: "\(p.displayName) key is missing from Keychain. Please re-enter it.",
                                color: RakuTheme.Color.warning
                            )
                        }
                    }
                    .listRowBackground(RakuTheme.Color.elevated)
                }

                Section(
                    header: Text("Cloud Providers (Optional)").foregroundColor(RakuTheme.Color.subtle),
                    footer: Text("Commercial LLMs are optional. No API key is required to run downloaded on-device GGUF models. Entered API keys are saved securely in iOS Keychain.").foregroundColor(RakuTheme.Color.subtle)
                ) {
                    ForEach([ProviderKind.gemini, .openai, .grok, .anthropic]) { provider in
                        NavigationLink(destination: ProviderKeyView(provider: provider)) {
                            HStack {
                                Text(provider.displayName)
                                    .font(RakuTheme.Font.headline())
                                    .foregroundColor(RakuTheme.Color.fg)
                                Spacer()
                                let configured = KeychainHelper.load(key: provider.keychainKey) != nil
                                Text(configured ? "Configured" : "Not Set")
                                    .font(RakuTheme.Font.footnote())
                                    .foregroundColor(configured ? RakuTheme.Color.ok : RakuTheme.Color.subtle)
                            }
                        }
                    }
                }
                .listRowBackground(RakuTheme.Color.elevated)

                Section(header: Text("Hugging Face").foregroundColor(RakuTheme.Color.subtle), footer: Text("Optional token to search and download from gated GGUF model repositories.").foregroundColor(RakuTheme.Color.subtle)) {
                    SecureField("User Access Token", text: $hfToken)
                        .foregroundColor(RakuTheme.Color.fg)
                        .onChange(of: hfToken) { val in
                            _ = KeychainHelper.save(key: "io.github.ddr-ai.rakullm.hfToken", secret: val)
                        }
                }
                .listRowBackground(RakuTheme.Color.elevated)

                Section(header: Text("Customization & Costs").foregroundColor(RakuTheme.Color.subtle)) {
                    NavigationLink(destination: PersonasView()) {
                        HStack {
                            Image(systemName: "person.crop.rectangle.stack")
                                .foregroundColor(RakuTheme.Color.accent)
                            Text("Personas & Prompts")
                                .foregroundColor(RakuTheme.Color.fg)
                        }
                    }

                    NavigationLink(destination: CostTableView()) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(RakuTheme.Color.ok)
                            Text("Token Pricing Table")
                                .foregroundColor(RakuTheme.Color.fg)
                        }
                    }
                }
                .listRowBackground(RakuTheme.Color.elevated)

                Section(header: Text("About RakuLLM").foregroundColor(RakuTheme.Color.subtle)) {
                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        Text("io.github.ddr-ai.rakullm")
                            .font(RakuTheme.Font.code(size: 11))
                            .foregroundColor(RakuTheme.Color.muted)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Release)")
                            .font(RakuTheme.Font.footnote())
                            .foregroundColor(RakuTheme.Color.muted)
                    }

                    HStack {
                        Text("Inference Engine")
                        Spacer()
                        Text("llama.cpp (GGUF)")
                            .font(RakuTheme.Font.footnote())
                            .foregroundColor(RakuTheme.Color.muted)
                    }
                }
                .listRowBackground(RakuTheme.Color.elevated)
            }
            .background(RakuTheme.Color.bg.edgesIgnoringSafeArea(.all))
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .onAppear {
                checkKeys()
                if let t = KeychainHelper.load(key: "io.github.ddr-ai.rakullm.hfToken") {
                    hfToken = t
                }
            }
        }
    }

    private func checkKeys() {
        var missing: [ProviderKind] = []
        for p in [ProviderKind.gemini, .openai, .grok, .anthropic] {
            if KeychainHelper.load(key: p.keychainKey) == nil {
                // Check if user previously marked this provider active
            }
        }
        self.missingKeyProviders = missing
    }
}
