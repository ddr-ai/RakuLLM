import Foundation

public enum ToolPermissionMode: String, Codable, CaseIterable, Identifiable {
    case inherit = "inherit"
    case allowAll = "allowAll"
    case confirmEach = "confirmEach"
    case allowlist = "allowlist"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .inherit: return "Inherit"
        case .allowAll: return "Allow All"
        case .confirmEach: return "Confirm Each"
        case .allowlist: return "Allowlist Only"
        }
    }
}

public enum ToolOverride: String, Codable, CaseIterable {
    case inherit = "inherit"
    case alwaysAllow = "alwaysAllow"
    case alwaysDeny = "alwaysDeny"
}

public struct MCPToolPolicy: Codable, Identifiable, Equatable {
    public var id: String { "\(serverID)::\(toolName)" }
    public var serverID: String
    public var toolName: String
    public var toolOverride: ToolOverride
    public var isConfirmedDestructive: Bool

    public init(
        serverID: String,
        toolName: String,
        toolOverride: ToolOverride = .inherit,
        isConfirmedDestructive: Bool = false
    ) {
        self.serverID = serverID
        self.toolName = toolName
        self.toolOverride = toolOverride
        self.isConfirmedDestructive = isConfirmedDestructive
    }
}
