import Foundation

public enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case gemini = "gemini"
    case openai = "openai"
    case grok = "grok"
    case anthropic = "anthropic"
    case local = "local"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gemini: return "Gemini"
        case .openai: return "OpenAI"
        case .grok: return "Grok"
        case .anthropic: return "Anthropic"
        case .local: return "Local (llama.cpp)"
        }
    }

    public var defaultModel: String {
        switch self {
        case .gemini: return "gemini-2.5-flash"
        case .openai: return "gpt-4o"
        case .grok: return "grok-2-latest"
        case .anthropic: return "claude-3-5-sonnet-20241022"
        case .local: return "local-gguf"
        }
    }

    public var isCloud: Bool {
        self != .local
    }

    public var keychainKey: String {
        "io.github.ddr-ai.rakullm.provider.\(rawValue).apiKey"
    }
}

public struct ProviderConfig: Codable, Identifiable {
    public var id: ProviderKind { kind }
    public var kind: ProviderKind
    public var isEnabled: Bool
    public var defaultModel: String

    public init(kind: ProviderKind, isEnabled: Bool = true, defaultModel: String? = nil) {
        self.kind = kind
        self.isEnabled = isEnabled
        self.defaultModel = defaultModel ?? kind.defaultModel
    }
}
