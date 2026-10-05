import Foundation

public struct Persona: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var icon: String
    public var systemPrompt: String
    public var isBuiltIn: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        icon: String = "person.fill",
        systemPrompt: String,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.isBuiltIn = isBuiltIn
    }

    public static let defaultAssistant = Persona(
        id: "built-in-default",
        name: "Helpful Assistant",
        icon: "sparkles",
        systemPrompt: "You are RakuLLM, a helpful, thoughtful, and capable AI assistant.",
        isBuiltIn: true
    )

    public static let codeExpert = Persona(
        id: "built-in-code",
        name: "Code Expert",
        icon: "chevron.left.forwardslash.chevron.right",
        systemPrompt: "You are an expert software engineer. Provide concise, robust, idiomatic code solutions. Prioritize correctness, memory efficiency, and modern best practices.",
        isBuiltIn: true
    )

    public static let concise = Persona(
        id: "built-in-concise",
        name: "Direct & Concise",
        icon: "bolt.fill",
        systemPrompt: "Answer directly, accurately, and concisely without filler, preamble, or repetition.",
        isBuiltIn: true
    )

    public static let mcpOrchestrator = Persona(
        id: "built-in-mcp",
        name: "Tool Orchestrator",
        icon: "wrench.and.screwdriver.fill",
        systemPrompt: "You are an intelligent assistant equipped with Model Context Protocol (MCP) tools. Analyze user instructions carefully, select appropriate tools when needed, and synthesize tool results clearly.",
        isBuiltIn: true
    )

    public static let allBuiltIns: [Persona] = [
        defaultAssistant,
        codeExpert,
        concise,
        mcpOrchestrator
    ]
}
