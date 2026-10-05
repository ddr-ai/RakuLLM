import Foundation
import SwiftData

@Model
public final class Conversation: Identifiable {
    public var id: String = UUID().uuidString
    public var title: String = "New Chat"
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var providerKindRaw: String = ProviderKind.gemini.rawValue
    public var modelIdentifier: String = "gemini-2.5-flash"
    public var personaID: String? = nil
    public var systemPromptOverride: String? = nil
    public var toolPermissionOverrideRaw: String = ToolPermissionMode.inherit.rawValue
    public var forkedFromID: String? = nil
    public var forkedAtMessageID: String? = nil
    public var pinned: Bool = false

    public var providerKind: ProviderKind {
        get { ProviderKind(rawValue: providerKindRaw) ?? .gemini }
        set { providerKindRaw = newValue.rawValue }
    }

    public var toolPermissionOverride: ToolPermissionMode {
        get { ToolPermissionMode(rawValue: toolPermissionOverrideRaw) ?? .inherit }
        set { toolPermissionOverrideRaw = newValue.rawValue }
    }

    public init(
        id: String = UUID().uuidString,
        title: String = "New Chat",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        providerKind: ProviderKind = .gemini,
        modelIdentifier: String? = nil,
        personaID: String? = nil,
        systemPromptOverride: String? = nil,
        toolPermissionOverride: ToolPermissionMode = .inherit,
        forkedFromID: String? = nil,
        forkedAtMessageID: String? = nil,
        pinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerKindRaw = providerKind.rawValue
        self.modelIdentifier = modelIdentifier ?? providerKind.defaultModel
        self.personaID = personaID
        self.systemPromptOverride = systemPromptOverride
        self.toolPermissionOverrideRaw = toolPermissionOverride.rawValue
        self.forkedFromID = forkedFromID
        self.forkedAtMessageID = forkedAtMessageID
        self.pinned = pinned
    }
}
