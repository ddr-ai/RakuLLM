import Foundation

public struct ChatRequestMessage: Codable, Equatable {
    public var role: String
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ChatToolDefinition: Codable, Equatable {
    public var name: String
    public var description: String
    public var inputSchemaJSON: String

    public init(name: String, description: String, inputSchemaJSON: String) {
        self.name = name
        self.description = description
        self.inputSchemaJSON = inputSchemaJSON
    }
}

public struct ChatRequest: Equatable {
    public var model: String
    public var messages: [ChatRequestMessage]
    public var systemPrompt: String?
    public var temperature: Double?
    public var topP: Double?
    public var maxOutputTokens: Int
    public var stopSequences: [String]?
    public var tools: [ChatToolDefinition]?

    public init(
        model: String,
        messages: [ChatRequestMessage],
        systemPrompt: String? = nil,
        temperature: Double? = 0.7,
        topP: Double? = 0.95,
        maxOutputTokens: Int = 2048,
        stopSequences: [String]? = nil,
        tools: [ChatToolDefinition]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.topP = topP
        self.maxOutputTokens = maxOutputTokens
        self.stopSequences = stopSequences
        self.tools = tools
    }
}
