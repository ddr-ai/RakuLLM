import SwiftUI

public struct ChatMessageCell: View {
    public let message: Message
    public let onEdit: () -> Void
    public let onRegenerate: () -> Void
    public let onFork: () -> Void
    public let onSelectVariant: (Int) -> Void

    public init(
        message: Message,
        onEdit: @escaping () -> Void,
        onRegenerate: @escaping () -> Void,
        onFork: @escaping () -> Void,
        onSelectVariant: @escaping (Int) -> Void
    ) {
        self.message = message
        self.onEdit = onEdit
        self.onRegenerate = onRegenerate
        self.onFork = onFork
        self.onSelectVariant = onSelectVariant
    }

    private var isUser: Bool {
        message.role == .user
    }

    public var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Header (Role & Variants indicator)
                HStack(spacing: 6) {
                    if !isUser {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(RakuTheme.Color.accent)
                        Text("Assistant")
                            .font(RakuTheme.Font.footnote())
                            .foregroundColor(RakuTheme.Color.subtle)
                    }

                    if message.variants.count > 1 {
                        HStack(spacing: 4) {
                            Button(action: {
                                if message.activeVariant > 0 {
                                    onSelectVariant(message.activeVariant - 1)
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 9))
                            }
                            .disabled(message.activeVariant == 0)

                            Text("\(message.activeVariant + 1)/\(message.variants.count)")
                                .font(RakuTheme.Font.footnote())

                            Button(action: {
                                if message.activeVariant < message.variants.count - 1 {
                                    onSelectVariant(message.activeVariant + 1)
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                            }
                            .disabled(message.activeVariant == message.variants.count - 1)
                        }
                        .foregroundColor(RakuTheme.Color.muted)
                        .padding(.horizontal, 4)
                        .background(RakuTheme.Color.canvas)
                        .cornerRadius(4)
                    }

                    Spacer()

                    // Context Menu for Edit / Regenerate / Fork
                    Menu {
                        Button(action: {
                            UIPasteboard.general.string = message.activeText
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        if isUser {
                            Button(action: onEdit) {
                                Label("Edit & Resend", systemImage: "pencil")
                            }
                        } else {
                            Button(action: onRegenerate) {
                                Label("Regenerate", systemImage: "arrow.clockwise")
                            }
                        }

                        Button(action: onFork) {
                            Label("Fork Chat From Here", systemImage: "arrow.triangle.branch")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(RakuTheme.Color.subtle)
                            .padding(4)
                    }
                }

                // Message Text
                Text(message.activeText)
                    .font(RakuTheme.Font.body())
                    .foregroundColor(isUser ? RakuTheme.Color.bg : RakuTheme.Color.fg)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(isUser ? RakuTheme.Color.fg : RakuTheme.Color.elevated)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isUser ? Color.clear : RakuTheme.Color.line, lineWidth: 1)
                    )

                // Metric chips for assistant message
                if !isUser {
                    MetricChipView(message: message)
                }
            }

            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
