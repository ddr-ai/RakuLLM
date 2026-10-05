import SwiftUI

@MainActor
public struct RootTabView: View {
    @ObservedObject public var env: AppEnvironment

    public init(env: AppEnvironment = AppEnvironment.shared) {
        self.env = env
    }

    public var body: some View {
        TabView {
            ChatView(orchestrator: env.orchestrator, mcpRegistry: env.mcpRegistry)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }

            ModelListView(downloadManager: env.downloadManager)
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }

            MCPServersView(registry: env.mcpRegistry)
                .tabItem {
                    Label("MCP", systemImage: "server.rack")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .preferredColorScheme(.dark)
        .tint(RakuTheme.Color.accent)
    }
}
