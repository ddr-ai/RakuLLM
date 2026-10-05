import Foundation

public enum StreamableHTTPError: LocalizedError, Equatable {
    case invalidURL
    case httpError(statusCode: Int, responseBody: String)
    case sessionExpired
    case payloadTooLarge
    case responseDecodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid MCP server URL."
        case .httpError(let code, let body): return "MCP HTTP Error \(code): \(body)"
        case .sessionExpired: return "MCP Session expired or not found."
        case .payloadTooLarge: return "MCP response body exceeded 8 MB buffer cap."
        case .responseDecodingFailed(let msg): return "Failed to decode MCP response: \(msg)"
        }
    }
}

public final class StreamableHTTP {
    public static let protocolVersion = "2025-06-18"
    public static let maxResponseBodyBytes = 8 * 1024 * 1024 // 8 MB (T8)

    public let endpoint: URL
    public let token: String?
    public private(set) var sessionID: String?
    public private(set) var negotiatedProtocolVersion: String?

    public init(endpoint: URL, token: String? = nil, sessionID: String? = nil) {
        self.endpoint = endpoint
        self.token = token
        self.sessionID = sessionID
        self.negotiatedProtocolVersion = nil
    }

    public func setSessionID(_ newID: String?) {
        self.sessionID = newID
    }

    public func setProtocolVersion(_ version: String?) {
        self.negotiatedProtocolVersion = version
    }

    /// Sends a JSON-RPC request over Streamable HTTP with automatic 404 session re-initialization retry
    public func send(
        request: JSONRPCRequest,
        reinitOn404: Bool = true,
        reinitHandler: (() async throws -> Void)? = nil
    ) async throws -> JSONRPCResponse {
        var urlReq = URLRequest(url: endpoint)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let t = token, !t.isEmpty {
            urlReq.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        let proto = negotiatedProtocolVersion ?? StreamableHTTP.protocolVersion
        urlReq.setValue(proto, forHTTPHeaderField: "MCP-Protocol-Version")

        if let sid = sessionID {
            urlReq.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        }

        // Explicitly: send NO Origin header
        urlReq.setValue(nil, forHTTPHeaderField: "Origin")

        let encoder = JSONEncoder()
        urlReq.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlReq)

        guard let http = response as? HTTPURLResponse else {
            throw StreamableHTTPError.httpError(statusCode: -1, responseBody: "Not HTTP response")
        }

        // Capture session ID header if returned
        if let newSessionId = http.value(forHTTPHeaderField: "Mcp-Session-Id") {
            self.sessionID = newSessionId
        }

        // Spec requirement: on 404 for any request carrying a session ID, drop session, re-init, retry once
        if http.statusCode == 404 && sessionID != nil && reinitOn404 {
            self.sessionID = nil
            if let reinit = reinitHandler {
                try await reinit()
                return try await send(request: request, reinitOn404: false, reinitHandler: nil)
            }
        }

        guard (200...299).contains(http.statusCode) else {
            let errorBody = String(data: data.prefix(2048), encoding: .utf8) ?? ""
            throw StreamableHTTPError.httpError(statusCode: http.statusCode, responseBody: errorBody)
        }

        guard data.count <= StreamableHTTP.maxResponseBodyBytes else {
            throw StreamableHTTPError.payloadTooLarge
        }

        // Response could be plain JSON or SSE
        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
        if contentType.contains("text/event-stream") {
            let codec = SSECodec()
            let messages = try codec.append(chunk: data) + codec.finish()
            for msg in messages {
                if let msgData = msg.data.data(using: .utf8),
                   let rpcResp = try? JSONDecoder().decode(JSONRPCResponse.self, from: msgData) {
                    return rpcResp
                }
            }
            throw StreamableHTTPError.responseDecodingFailed("No valid JSON-RPC payload in SSE stream")
        } else {
            do {
                return try JSONDecoder().decode(JSONRPCResponse.self, from: data)
            } catch {
                throw StreamableHTTPError.responseDecodingFailed(error.localizedDescription)
            }
        }
    }
}
