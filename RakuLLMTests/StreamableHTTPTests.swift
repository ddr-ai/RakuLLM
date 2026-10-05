import XCTest
@testable import RakuLLM

final class StreamableHTTPTests: XCTestCase {
    func testHeaderConfiguration() {
        let endpoint = URL(string: "https://example.com/mcp")!
        let transport = StreamableHTTP(endpoint: endpoint, token: "test-token-123", sessionID: "sess-456")

        XCTAssertEqual(transport.endpoint, endpoint)
        XCTAssertEqual(transport.token, "test-token-123")
        XCTAssertEqual(transport.sessionID, "sess-456")
    }

    func testSessionIdUpdate() {
        let transport = StreamableHTTP(endpoint: URL(string: "http://localhost:8080/mcp")!)
        XCTAssertNil(transport.sessionID)

        transport.setSessionID("sess-new-789")
        XCTAssertEqual(transport.sessionID, "sess-new-789")

        transport.setProtocolVersion("2025-06-18")
        XCTAssertEqual(transport.negotiatedProtocolVersion, "2025-06-18")
    }

    func testMCPConfigImporterURLAndCommand() throws {
        let json = """
        {
            "mcpServers": {
                "weather": {
                    "url": "https://api.weather.com/mcp"
                },
                "local-git": {
                    "command": "git-mcp",
                    "args": ["--verbose"]
                }
            }
        }
        """

        let result = try MCPConfigImporter.shared.parseConfig(jsonString: json)

        // 1 server imported
        XCTAssertEqual(result.importedServers.count, 1)
        XCTAssertEqual(result.importedServers[0].name, "weather")
        XCTAssertEqual(result.importedServers[0].url, "https://api.weather.com/mcp")

        // 1 command recorded unsupported with reason
        XCTAssertEqual(result.unsupportedEntries.count, 1)
        XCTAssertEqual(result.unsupportedEntries[0].serverName, "local-git")
        XCTAssertEqual(result.unsupportedEntries[0].command, "git-mcp")
        XCTAssertTrue(result.unsupportedEntries[0].reason.contains("stdio transport"))
    }
}
