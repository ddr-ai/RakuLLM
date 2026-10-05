import Foundation

public final class ChatTemplateProbe {
    public static let shared = ChatTemplateProbe()

    public init() {}

    /// Checks if a chat template or model natively supports tool calling
    public func probeSupportsTools(chatTemplate: String?) -> Bool {
        guard let template = chatTemplate, !template.isEmpty else {
            return false
        }

        // Jinja2 tool markers commonly found in Llama-3-Instruct, Mistral, Qwen2.5, Hermes, etc.
        let toolKeywords = [
            "tools",
            "tool_call",
            "tool_calls",
            "<|tool_call|>",
            "<|start_header_id|>ipython<|end_header_id|>",
            "[TOOL_CALLS]",
            "<tool_call>",
            "functions"
        ]

        for kw in toolKeywords {
            if template.contains(kw) {
                return true
            }
        }

        return false
    }
}
