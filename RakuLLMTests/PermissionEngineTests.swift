import XCTest
@testable import RakuLLM

final class PermissionEngineTests: XCTestCase {
    let engine = PermissionEngine.shared

    func testDestructiveNameMatching() {
        XCTAssertTrue(engine.isDestructive(toolName: "delete_database", description: "Deletes the target DB"))
        XCTAssertTrue(engine.isDestructive(toolName: "run_shell_command", description: "Executes a bash script"))
        XCTAssertTrue(engine.isDestructive(toolName: "remove_file", description: "Removes given file"))
        XCTAssertTrue(engine.isDestructive(toolName: "send_payment", description: "Transfers funds"))

        XCTAssertFalse(engine.isDestructive(toolName: "read_file", description: "Reads contents of a file"))
        XCTAssertFalse(engine.isDestructive(toolName: "search_docs", description: "Searches documentation"))
    }

    func testPrecedenceAlwaysDeny() {
        let server = MCPServerRecord(name: "TestServer", url: "https://test.com", mode: .allowAll)
        let tool = ChatToolDefinition(name: "safe_tool", description: "Does safe stuff", inputSchemaJSON: "{}")
        let policy = MCPToolPolicy(serverID: server.id, toolName: "safe_tool", toolOverride: .alwaysDeny)

        // Even with allowAll in conversation and server, alwaysDeny must deny
        let decision = engine.evaluate(
            server: server,
            tool: tool,
            policy: policy,
            conversationMode: .allowAll
        )

        XCTAssertEqual(decision, .deny(reason: "Tool is explicitly denied by user policy."))
    }

    func testPrecedenceAlwaysAllow() {
        let server = MCPServerRecord(name: "TestServer", url: "https://test.com", mode: .confirmEach)
        let tool = ChatToolDefinition(name: "safe_tool", description: "Does safe stuff", inputSchemaJSON: "{}")
        let policy = MCPToolPolicy(serverID: server.id, toolName: "safe_tool", toolOverride: .alwaysAllow)

        // Even if conversation and server say confirmEach, alwaysAllow must allow non-destructive tool
        let decision = engine.evaluate(
            server: server,
            tool: tool,
            policy: policy,
            conversationMode: .confirmEach
        )

        XCTAssertEqual(decision, .allow)
    }

    func testDestructiveToolForcesOneTimeConfirmationEvenUnderAllowAll() {
        let server = MCPServerRecord(name: "TestServer", url: "https://test.com", mode: .allowAll)
        let tool = ChatToolDefinition(name: "drop_table", description: "Drops database table", inputSchemaJSON: "{}")
        let policy = MCPToolPolicy(serverID: server.id, toolName: "drop_table", toolOverride: .inherit, isConfirmedDestructive: false)

        let decision = engine.evaluate(
            server: server,
            tool: tool,
            policy: policy,
            conversationMode: .allowAll
        )

        if case .confirm(let reason) = decision {
            XCTAssertTrue(reason.contains("destructive"))
        } else {
            XCTFail("Expected .confirm for destructive tool, got \(decision)")
        }
    }

    func testConfirmedDestructiveProceeds() {
        let server = MCPServerRecord(name: "TestServer", url: "https://test.com", mode: .allowAll)
        let tool = ChatToolDefinition(name: "drop_table", description: "Drops database table", inputSchemaJSON: "{}")
        let policy = MCPToolPolicy(serverID: server.id, toolName: "drop_table", toolOverride: .inherit, isConfirmedDestructive: true)

        let decision = engine.evaluate(
            server: server,
            tool: tool,
            policy: policy,
            conversationMode: .allowAll
        )

        XCTAssertEqual(decision, .allow)
    }

    func testConversationOverridePrecedesServerDefault() {
        let server = MCPServerRecord(name: "TestServer", url: "https://test.com", mode: .allowAll)
        let tool = ChatToolDefinition(name: "safe_tool", description: "Safe", inputSchemaJSON: "{}")

        // Conversation override is confirmEach -> must confirm
        let decision = engine.evaluate(
            server: server,
            tool: tool,
            policy: nil,
            conversationMode: .confirmEach
        )

        if case .confirm = decision {
            // Success
        } else {
            XCTFail("Expected confirm from conversation override, got \(decision)")
        }
    }

    func testInheritDefersToServerDefault() {
        let server = MCPServerRecord(name: "TestServer", url: "https://test.com", mode: .confirmEach)
        let tool = ChatToolDefinition(name: "safe_tool", description: "Safe", inputSchemaJSON: "{}")

        // Conversation mode is inherit -> uses server mode confirmEach
        let decision = engine.evaluate(
            server: server,
            tool: tool,
            policy: nil,
            conversationMode: .inherit
        )

        if case .confirm = decision {
            // Success
        } else {
            XCTFail("Expected confirm from inherited server mode, got \(decision)")
        }
    }
}
