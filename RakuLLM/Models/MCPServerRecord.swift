import Foundation

public struct MCPServerRecord: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var url: String
    public var transport: String
    public var sessionID: String?
    public var protocolVersion: String?
    public var serverInfoJSON: String?
    public var lastConnectedAt: Date?
    public var lastError: String?
    public var mode: ToolPermissionMode
    public var enabled: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        url: String,
        transport: String = "http",
        sessionID: String? = nil,
        protocolVersion: String? = nil,
        serverInfoJSON: String? = nil,
        lastConnectedAt: Date? = nil,
        lastError: String? = nil,
        mode: ToolPermissionMode = .allowAll,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.transport = transport
        self.sessionID = sessionID
        self.protocolVersion = protocolVersion
        self.serverInfoJSON = serverInfoJSON
        self.lastConnectedAt = lastConnectedAt
        self.lastError = lastError
        self.mode = mode
        self.enabled = enabled
    }

    public var keychainTokenKey: String {
        "io.github.ddr-ai.rakullm.mcp.\(id).token"
    }
}
