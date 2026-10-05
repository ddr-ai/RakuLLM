import Foundation

public struct WindowBudget {
    public let nCtx: Int
    public let maxOutputTokens: Int
    public let reserve: Int
    public let budget: Int

    public init(nCtx: Int, requestedMaxOutputTokens: Int = 2048) {
        self.nCtx = nCtx
        self.reserve = min(requestedMaxOutputTokens, nCtx / 4)
        self.budget = max(0, nCtx - self.reserve)
        self.maxOutputTokens = requestedMaxOutputTokens
    }
}

public struct WindowedHistory {
    public let includedMessages: [ChatRequestMessage]
    public let prunedCount: Int
    public let totalTokensUsed: Int
    public let fitsContext: Bool
    public let singleTurnTooLarge: Bool
}

public final class TokenMeter {
    public static let shared = TokenMeter()

    public init() {}

    /// T1: Conservative token estimate for text: ceil(chars / 3.5) + 4 per message, rounded up.
    public func estimateTokens(for text: String) -> Int {
        guard !text.isEmpty else { return 4 }
        let raw = Double(text.count) / 3.5
        return Int(ceil(raw)) + 4
    }

    /// T2: Computes window budget based on model context length and desired output reservation
    public func computeBudget(nCtx: Int, requestedMaxOutputTokens: Int = 2048) -> WindowBudget {
        WindowBudget(nCtx: nCtx, requestedMaxOutputTokens: requestedMaxOutputTokens)
    }

    /// T4: Explicit output cap: max(256, n_ctx - promptTokens)
    public func computeMaxOutputTokens(nCtx: Int, promptTokens: Int) -> Int {
        return max(256, nCtx - promptTokens)
    }

    /// T3: History windowing walking newest-to-oldest.
    /// System prompt is retained verbatim. Walk turns newest-to-oldest while used + turnTokens <= windowBudget.
    public func windowMessages(
        messages: [ChatRequestMessage],
        systemPrompt: String?,
        budget: WindowBudget
    ) -> WindowedHistory {
        let systemTokens = systemPrompt.map { estimateTokens(for: $0) } ?? 0
        var availableBudget = budget.budget - systemTokens

        if availableBudget <= 0 {
            return WindowedHistory(
                includedMessages: [],
                prunedCount: messages.count,
                totalTokensUsed: systemTokens,
                fitsContext: false,
                singleTurnTooLarge: true
            )
        }

        guard let newest = messages.last else {
            return WindowedHistory(
                includedMessages: [],
                prunedCount: 0,
                totalTokensUsed: systemTokens,
                fitsContext: true,
                singleTurnTooLarge: false
            )
        }

        let newestTokens = estimateTokens(for: newest.content)
        if newestTokens > availableBudget {
            return WindowedHistory(
                includedMessages: [],
                prunedCount: messages.count,
                totalTokensUsed: systemTokens + newestTokens,
                fitsContext: false,
                singleTurnTooLarge: true
            )
        }

        var includedRev: [ChatRequestMessage] = []
        var usedTokens = 0

        // Walk newest to oldest
        for msg in messages.reversed() {
            let tokens = estimateTokens(for: msg.content)
            if usedTokens + tokens <= availableBudget {
                includedRev.append(msg)
                usedTokens += tokens
            } else {
                break
            }
        }

        let included = Array(includedRev.reversed())
        let pruned = messages.count - included.count

        return WindowedHistory(
            includedMessages: included,
            prunedCount: pruned,
            totalTokensUsed: systemTokens + usedTokens,
            fitsContext: true,
            singleTurnTooLarge: false
        )
    }

    /// T6: Hard cap 64 KB of text per tool result.
    /// Truncate on UTF-8 boundary and append notice.
    public func truncateToolResultIfNeeded(_ result: String, maxBytes: Int = 64 * 1024) -> String {
        guard let data = result.data(using: .utf8), data.count > maxBytes else {
            return result
        }

        let totalBytes = data.count
        var truncatedData = data.prefix(maxBytes)

        // Ensure valid UTF-8 boundary by dropping bytes if incomplete code point
        while !truncatedData.isEmpty && String(data: truncatedData, encoding: .utf8) == nil {
            truncatedData = truncatedData.dropLast()
        }

        let truncatedString = String(data: truncatedData, encoding: .utf8) ?? ""
        let notice = "\n[truncated \(totalBytes - truncatedData.count) of \(totalBytes) bytes — re-run the tool with a narrower query]"
        return truncatedString + notice
    }
}
