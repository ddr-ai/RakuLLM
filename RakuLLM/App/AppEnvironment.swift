import Foundation
import Combine

@MainActor
public final class AppEnvironment: ObservableObject {
    public static let shared = AppEnvironment()

    public let orchestrator: ChatOrchestrator
    public let downloadManager: DownloadManager
    public let mcpRegistry: MCPRegistry

    public init() {
        self.orchestrator = ChatOrchestrator()
        self.downloadManager = DownloadManager.shared
        self.mcpRegistry = MCPRegistry.shared
    }
}
