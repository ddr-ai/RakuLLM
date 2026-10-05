import Foundation
import SwiftData

public enum MessageRole: String, Codable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
    case tool = "tool"
}

@Model
public final class Message: Identifiable {
    public var id: String = UUID().uuidString
    public var conversationID: String = ""
    public var sequence: Int = 0
    public var roleRaw: String = MessageRole.user.rawValue
    public var text: String = ""
    public var createdAt: Date = Date()
    public var variants: [String] = []
    public var activeVariant: Int = 0

    // Metric chips & tracking
    public var tokensIn: Int = 0
    public var tokensOut: Int = 0
    public var ttps: Double = 0.0          // Tokens per second
    public var firstTokenMs: Double = 0.0  // Time to first token
    public var durationMs: Double = 0.0    // Total stream duration
    public var costUSD: Double = 0.0
    public var isUsageEstimated: Bool = false
    public var toolInvocationID: String? = nil

    public var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    public var activeText: String {
        if variants.indices.contains(activeVariant) {
            return variants[activeVariant]
        }
        return text
    }

    public init(
        id: String = UUID().uuidString,
        conversationID: String,
        sequence: Int,
        role: MessageRole,
        text: String,
        createdAt: Date = Date(),
        variants: [String] = [],
        activeVariant: Int = 0,
        tokensIn: Int = 0,
        tokensOut: Int = 0,
        ttps: Double = 0.0,
        firstTokenMs: Double = 0.0,
        durationMs: Double = 0.0,
        costUSD: Double = 0.0,
        isUsageEstimated: Bool = false,
        toolInvocationID: String? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.sequence = sequence
        self.roleRaw = role.rawValue
        self.text = text
        self.createdAt = createdAt
        let initialVariants = variants.isEmpty ? [text] : variants
        self.variants = initialVariants
        self.activeVariant = activeVariant
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.ttps = ttps
        self.firstTokenMs = firstTokenMs
        self.durationMs = durationMs
        self.costUSD = costUSD
        self.isUsageEstimated = isUsageEstimated
        self.toolInvocationID = toolInvocationID
    }

    public func updateActiveText(_ newText: String) {
        self.text = newText
        if variants.indices.contains(activeVariant) {
            variants[activeVariant] = newText
        } else {
            variants.append(newText)
            activeVariant = variants.count - 1
        }
    }

    public func appendVariant(_ newText: String) {
        variants.append(newText)
        activeVariant = variants.count - 1
        self.text = newText
    }
}
