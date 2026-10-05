import Foundation

public final class MCPClient {
    public let server: MCPServerRecord
    public let transport: StreamableHTTP

    public init(server: MCPServerRecord, token: String? = nil) {
        self.server = server
        let endpoint = URL(string: server.url) ?? URL(string: "http://localhost")!
        self.transport = StreamableHTTP(endpoint: endpoint, token: token, sessionID: server.sessionID)
    }

    /// Initializes connection, captures session ID, sends initialized notification, and fetches tools
    public func connect() async throws -> [ChatToolDefinition] {
        let clientInfo: [String: Any] = [
            "name": "RakuLLM-iOS",
            "version": "1.0.0"
        ]
        let capabilities: [String: Any] = [
            "tools": ["listChanged": true]
        ]
        let initParams: [String: Any] = [
            "protocolVersion": StreamableHTTP.protocolVersion,
            "capabilities": capabilities,
            "clientInfo": clientInfo
        ]

        let initReq = JSONRPCRequest(
            id: UUID().uuidString,
            method: "initialize",
            params: AnyCodable(initParams)
        )

        let initResp = try await transport.send(request: initReq, reinitOn404: false)
        if let err = initResp.error {
            throw StreamableHTTPError.httpError(statusCode: 500, responseBody: err.message)
        }

        // Send notifications/initialized
        let notifyReq = JSONRPCRequest(
            id: nil, // notification has no ID
            method: "notifications/initialized",
            params: nil
        )
        _ = try? await transport.send(request: notifyReq, reinitOn404: false)

        return try await fetchTools()
    }

    /// Fetches tool definitions via `tools/list`
    public func fetchTools() async throws -> [ChatToolDefinition] {
        let listReq = JSONRPCRequest(
            id: UUID().uuidString,
            method: "tools/list",
            params: nil
        )

        let response = try await transport.send(request: listReq, reinitOn404: true) { [weak self] in
            _ = try await self?.connect()
        }

        guard let res = response.result?.value as? [String: Any],
              let toolsArray = res["tools"] as? [[String: Any]] else {
            return []
        }

        var results: [ChatToolDefinition] = []
        for t in toolsArray {
            guard let name = t["name"] as? String else { continue }
            let desc = t["description"] as? String ?? ""
            let schema = t["inputSchema"] as? [String: Any] ?? [:]
            let schemaData = (try? JSONSerialization.data(withJSONObject: schema)) ?? Data()
            let schemaJSON = String(data: schemaData, encoding: .utf8) ?? "{}"

            results.append(ChatToolDefinition(name: name, description: desc, inputSchemaJSON: schemaJSON))
        }

        // Update ToolCatalog
        ToolCatalog.shared.setTools(serverID: server.id, tools: results)
        return results
    }

    /// Calls a tool via `tools/call` and applies T6 64 KB truncation on the result text
    public func callTool(name: String, argumentsJSON: String) async throws -> String {
        let argsObj = (argumentsJSON.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) }) ?? [:]
        let params: [String: Any] = [
            "name": name,
            "arguments": argsObj
        ]

        let callReq = JSONRPCRequest(
            id: UUID().uuidString,
            method: "tools/call",
            params: AnyCodable(params)
        )

        let resp = try await transport.send(request: callReq, reinitOn404: true) { [weak self] in
            _ = try await self?.connect()
        }

        if let err = resp.error {
            throw StreamableHTTPError.httpError(statusCode: 500, responseBody: err.message)
        }

        var resultText = ""
        if let res = resp.result?.value as? [String: Any],
           let contentList = res["content"] as? [[String: Any]] {
            for item in contentList {
                if let text = item["text"] as? String {
                    resultText += text
                }
            }
        }

        // T6: Hard cap 64 KB of text per result. Truncate on UTF-8 boundary
        return TokenMeter.shared.truncateToolResultIfNeeded(resultText, maxBytes: 64 * 1024)
    }
}
