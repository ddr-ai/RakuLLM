import Foundation
import Combine

public final class MCPRegistry: ObservableObject {
    public static let shared = MCPRegistry()

    @Published public var servers: [MCPServerRecord] = []
    @Published public var policies: [String: MCPToolPolicy] = [:] // key: serverID::toolName
    private var clients: [String: MCPClient] = [:]

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("mcp_servers.json")
    }

    private var policiesURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("mcp_policies.json")
    }

    public init() {
        loadFromDisk()
    }

    public func addServer(_ server: MCPServerRecord, token: String? = nil) {
        if let idx = servers.firstIndex(where: { $0.id == server.id }) {
            servers[idx] = server
        } else {
            servers.append(server)
        }

        if let t = token, !t.isEmpty {
            _ = KeychainHelper.save(key: server.keychainTokenKey, secret: t)
        }

        clients[server.id] = MCPClient(server: server, token: token)
        saveToDisk()
    }

    public func removeServer(id: String) {
        servers.removeAll(where: { $0.id == id })
        clients.removeValue(forKey: id)
        ToolCatalog.shared.invalidate(serverID: id)
        _ = KeychainHelper.delete(key: "io.github.ddr-ai.rakullm.mcp.\(id).token")
        saveToDisk()
    }

    public func getClient(serverID: String) -> MCPClient? {
        if let client = clients[serverID] {
            return client
        }
        guard let server = servers.first(where: { $0.id == serverID }) else { return nil }
        let token = KeychainHelper.load(key: server.keychainTokenKey)
        let client = MCPClient(server: server, token: token)
        clients[serverID] = client
        return client
    }

    public func updatePolicy(_ policy: MCPToolPolicy) {
        policies[policy.id] = policy
        saveToDisk()
    }

    public func getPolicy(serverID: String, toolName: String) -> MCPToolPolicy? {
        policies["\(serverID)::\(toolName)"]
    }

    public func saveToDisk() {
        if let data = try? JSONEncoder().encode(servers) {
            try? data.write(to: storageURL)
        }
        if let data = try? JSONEncoder().encode(policies) {
            try? data.write(to: policiesURL)
        }
    }

    public func loadFromDisk() {
        if let data = try? Data(contentsOf: storageURL),
           let loaded = try? JSONDecoder().decode([MCPServerRecord].self, from: data) {
            self.servers = loaded
        }
        if let data = try? Data(contentsOf: policiesURL),
           let loaded = try? JSONDecoder().decode([String: MCPToolPolicy].self, from: data) {
            self.policies = loaded
        }
    }
}
