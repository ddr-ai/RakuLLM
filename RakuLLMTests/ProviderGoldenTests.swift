import XCTest
@testable import RakuLLM

final class ProviderGoldenTests: XCTestCase {
    let testRequest = ChatRequest(
        model: "test-model",
        messages: [
            ChatRequestMessage(role: "user", content: "Hello world")
        ],
        systemPrompt: "You are a test assistant.",
        temperature: 0.7,
        topP: 0.95,
        maxOutputTokens: 1024,
        tools: [
            ChatToolDefinition(name: "get_weather", description: "Get weather", inputSchemaJSON: "{\"type\":\"object\"}")
        ]
    )

    func testGeminiGoldenRequest() throws {
        let provider = GeminiProvider()
        let data = try provider.buildRequestBody(request: testRequest)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json?["contents"])
        let contents = json?["contents"] as? [[String: Any]]
        XCTAssertEqual(contents?.first?["role"] as? String, "user")

        let sys = json?["systemInstruction"] as? [String: Any]
        let sysParts = sys?["parts"] as? [[String: Any]]
        XCTAssertEqual(sysParts?.first?["text"] as? String, "You are a test assistant.")

        let genConfig = json?["generationConfig"] as? [String: Any]
        XCTAssertEqual(genConfig?["maxOutputTokens"] as? Int, 1024)
        XCTAssertEqual(genConfig?["temperature"] as? Double, 0.7)

        let tools = json?["tools"] as? [[String: Any]]
        let funcDecls = tools?.first?["functionDeclarations"] as? [[String: Any]]
        XCTAssertEqual(funcDecls?.first?["name"] as? String, "get_weather")
    }

    func testOpenAIGoldenRequest() throws {
        let provider = OpenAIProvider()
        let data = try provider.buildRequestBody(request: testRequest)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["model"] as? String, "test-model")
        XCTAssertEqual(json?["max_tokens"] as? Int, 1024)
        XCTAssertEqual(json?["stream"] as? Bool, true)

        let streamOptions = json?["stream_options"] as? [String: Any]
        XCTAssertEqual(streamOptions?["include_usage"] as? Bool, true)

        let messages = json?["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.first?["role"] as? String, "system")
        XCTAssertEqual(messages?.last?["role"] as? String, "user")

        let tools = json?["tools"] as? [[String: Any]]
        let firstTool = tools?.first?["function"] as? [String: Any]
        XCTAssertEqual(firstTool?["name"] as? String, "get_weather")
    }

    func testGrokGoldenRequest() throws {
        let provider = GrokProvider()
        let data = try provider.buildRequestBody(request: testRequest)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["model"] as? String, "test-model")
        XCTAssertEqual(json?["stream"] as? Bool, true)
    }

    func testAnthropicGoldenRequest() throws {
        let provider = AnthropicProvider()
        let data = try provider.buildRequestBody(request: testRequest)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["model"] as? String, "test-model")
        XCTAssertEqual(json?["system"] as? String, "You are a test assistant.")
        XCTAssertEqual(json?["max_tokens"] as? Int, 1024)
        XCTAssertEqual(json?["stream"] as? Bool, true)

        let messages = json?["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.first?["role"] as? String, "user")
        XCTAssertEqual(messages?.first?["content"] as? String, "Hello world")

        let tools = json?["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.first?["name"] as? String, "get_weather")
    }
}
