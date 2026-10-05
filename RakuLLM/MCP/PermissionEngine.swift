import Foundation

public enum PermissionDecision: Equatable {
    case allow
    case confirm(reason: String)
    case deny(reason: String)
}

public final class PermissionEngine {
    public static let shared = PermissionEngine()

    public static let destructiveKeywords: Set<String> = [
        "delete", "remove", "destroy", "drop", "erase",
        "write", "send", "post", "put", "patch", "create",
        "exec", "run", "shell", "command", "publish",
        "deploy", "transfer", "invoice", "payment", "revoke"
    ]

    public init() {}

    /// Checks if a tool's name or description contains a destructive action keyword
    public func isDestructive(toolName: String, description: String) -> Bool {
        let combined = "\(toolName) \(description)".lowercased()
        let words = combined.components(separatedBy: CharacterSet.alphanumerics.inverted)
        for word in words where !word.isEmpty {
            if PermissionEngine.destructiveKeywords.contains(word) {
                return true
            }
        }
        return false
    }

    /// Evaluates permission decision across the 4-level precedence hierarchy:
    /// 1. Tool override: alwaysDeny -> DENY
    /// 2. Tool override: alwaysAllow -> ALLOW (unless destructive keyword requires one-time confirmation)
    /// 3. Destructive-name heuristic (if not yet confirmed, requires confirmation regardless of mode)
    /// 4. Conversation override (if not inherit): allowAll / confirmEach / allowlist
    /// 5. Server default mode: allowAll / confirmEach / allowlist
    public func evaluate(
        server: MCPServerRecord,
        tool: ChatToolDefinition,
        policy: MCPToolPolicy?,
        conversationMode: ToolPermissionMode
    ) -> PermissionDecision {
        // 1. Tool override: alwaysDeny
        if let p = policy, p.toolOverride == .alwaysDeny {
            return .deny(reason: "Tool is explicitly denied by user policy.")
        }

        // 2. Destructive-name check: requires one-time confirmation unless already confirmed
        let destructive = isDestructive(toolName: tool.name, description: tool.description)
        if destructive && (policy?.isConfirmedDestructive != true) {
            return .confirm(reason: "Tool '\(tool.name)' appears destructive and requires one-time confirmation.")
        }

        // 3. Tool override: alwaysAllow
        if let p = policy, p.toolOverride == .alwaysAllow {
            return .allow
        }

        // 4. Conversation override (if not inherit)
        if conversationMode != .inherit {
            return applyMode(conversationMode, toolName: tool.name, policy: policy, contextLabel: "conversation override")
        }

        // 5. Server default mode
        return applyMode(server.mode, toolName: tool.name, policy: policy, contextLabel: "server default")
    }

    private func applyMode(
        _ mode: ToolPermissionMode,
        toolName: String,
        policy: MCPToolPolicy?,
        contextLabel: String
    ) -> PermissionDecision {
        switch mode {
        case .allowAll:
            return .allow
        case .confirmEach:
            return .confirm(reason: "Requires confirmation per \(contextLabel).")
        case .allowlist:
            if let p = policy, p.toolOverride == .alwaysAllow {
                return .allow
            }
            return .deny(reason: "Tool '\(toolName)' is not on the allowlist.")
        case .inherit:
            return .allow
        }
    }
}
