import Foundation

public final class ToolCatalog: ObservableObject {
    public static let shared = ToolCatalog()

    // serverID -> [ChatToolDefinition]
    @Published public private(set) var toolsByServer: [String: [ChatToolDefinition]] = [:]

    public init() {}

    public func setTools(serverID: String, tools: [ChatToolDefinition]) {
        toolsByServer[serverID] = tools
    }

    /// T8: Invalidate cache when server emits notifications/tools/list_changed
    public func invalidate(serverID: String) {
        toolsByServer.removeValue(forKey: serverID)
    }

    public func allEnabledTools(enabledServerIDs: Set<String>) -> [ChatToolDefinition] {
        var all: [ChatToolDefinition] = []
        for id in enabledServerIDs {
            if let tools = toolsByServer[id] {
                all.append(contentsOf: tools)
            }
        }
        return all
    }

    public func findTool(name: String) -> (serverID: String, tool: ChatToolDefinition)? {
        for (serverID, tools) in toolsByServer {
            if let match = tools.first(where: { $0.name == name }) {
                return (serverID, match)
            }
        }
        return nil
    }
}
