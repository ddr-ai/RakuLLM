import XCTest
@testable import RakuLLM

final class JSONRPCTests: XCTestCase {
    func testRequestEncoding() throws {
        let req = JSONRPCRequest(id: "1", method: "tools/list", params: nil)
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(json?["id"] as? String, "1")
        XCTAssertEqual(json?["method"] as? String, "tools/list")
    }

    func testNotificationRequestEncoding() throws {
        let notif = JSONRPCRequest(id: nil, method: "notifications/initialized", params: nil)
        let data = try JSONEncoder().encode(notif)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["jsonrpc"] as? String, "2.0")
        XCTAssertNil(json?["id"])
        XCTAssertEqual(json?["method"] as? String, "notifications/initialized")
    }

    func testSuccessResponseDecoding() throws {
        let rawJSON = """
        {
            "jsonrpc": "2.0",
            "id": "abc-123",
            "result": {
                "tools": [
                    {"name": "calculator", "description": "performs arithmetic"}
                ]
            }
        }
        """.data(using: .utf8)!

        let resp = try JSONDecoder().decode(JSONRPCResponse.self, from: rawJSON)
        XCTAssertEqual(resp.jsonrpc, "2.0")
        XCTAssertEqual(resp.id, "abc-123")
        XCTAssertNil(resp.error)

        let resultDict = resp.result?.value as? [String: Any]
        let tools = resultDict?["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.count, 1)
        XCTAssertEqual(tools?[0]["name"] as? String, "calculator")
    }

    func testErrorResponseDecoding() throws {
        let rawJSON = """
        {
            "jsonrpc": "2.0",
            "id": "error-1",
            "error": {
                "code": -32601,
                "message": "Method not found"
            }
        }
        """.data(using: .utf8)!

        let resp = try JSONDecoder().decode(JSONRPCResponse.self, from: rawJSON)
        XCTAssertEqual(resp.jsonrpc, "2.0")
        XCTAssertEqual(resp.id, "error-1")
        XCTAssertNotNil(resp.error)
        XCTAssertEqual(resp.error?.code, -32601)
        XCTAssertEqual(resp.error?.message, "Method not found")
    }
}
