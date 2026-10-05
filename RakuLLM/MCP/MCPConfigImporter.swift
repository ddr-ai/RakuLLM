import Foundation

public struct UnsupportedCommandEntry: Equatable {
    public let serverName: String
    public let command: String
    public let reason: String

    public init(serverName: String, command: String, reason: String) {
        self.serverName = serverName
        self.command = command
        self.reason = reason
    }
}

public struct MCPImportResult: Equatable {
    public var importedServers: [MCPServerRecord]
    public var unsupportedEntries: [UnsupportedCommandEntry]

    public init(importedServers: [MCPServerRecord] = [], unsupportedEntries: [UnsupportedCommandEntry] = []) {
        self.importedServers = importedServers
        self.unsupportedEntries = unsupportedEntries
    }
}

public final class MCPConfigImporter {
    public static let shared = MCPConfigImporter()

    public init() {}

    /// Parses mcp.json format accepting both `mcpServers` and `servers` keys.
    /// URL entries are imported as remote servers.
    /// Command entries are recorded as unsupported with explicit reason.
    public func parseConfig(jsonString: String) throws -> MCPImportResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid UTF-8 string"))
        }
        return try parseConfig(data: data)
    }

    public func parseConfig(data: Data) throws -> MCPImportResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Root JSON is not an object"))
        }

        // Accept either "mcpServers" or "servers"
        let serversDict = (root["mcpServers"] as? [String: Any]) ?? (root["servers"] as? [String: Any]) ?? root

        var imported: [MCPServerRecord] = []
        var unsupported: [UnsupportedCommandEntry] = []

        for (name, value) in serversDict {
            guard let config = value as? [String: Any] else { continue }

            if let urlStr = config["url"] as? String {
                // Remote Streamable HTTP server
                let server = MCPServerRecord(
                    name: name,
                    url: urlStr,
                    transport: "http",
                    mode: .allowAll,
                    enabled: true
                )
                imported.append(server)
            } else if let cmd = config["command"] as? String {
                // Command stdio server: out of scope for iOS, record unsupported with reason
                let entry = UnsupportedCommandEntry(
                    serverName: name,
                    command: cmd,
                    reason: "Local subprocesses (stdio transport) are not supported on iOS sandboxed apps. Connect via Streamable HTTP URL instead."
                )
                unsupported.append(entry)
            } else {
                let entry = UnsupportedCommandEntry(
                    serverName: name,
                    command: "unknown",
                    reason: "Missing 'url' or 'command' field in server configuration."
                )
                unsupported.append(entry)
            }
        }

        return MCPImportResult(importedServers: imported, unsupportedEntries: unsupported)
    }
}
