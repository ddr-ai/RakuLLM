import SwiftUI

public enum MessageSegment: Identifiable {
    public var id: String {
        switch self {
        case .text(let t, let id): return "text-\(id)"
        case .code(let c, let lang, let id): return "code-\(id)"
        }
    }

    case text(content: String, id: String)
    case code(content: String, language: String, id: String)
}

public struct FormattedMessageView: View {
    public let text: String
    public let isUser: Bool

    public init(text: String, isUser: Bool = false) {
        self.text = text
        self.isUser = isUser
    }

    private var segments: [MessageSegment] {
        parseSegments(text)
    }

    public var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
            ForEach(segments) { segment in
                switch segment {
                case .text(let content, _):
                    if isUser {
                        Text(content)
                            .font(RakuTheme.Font.body())
                            .foregroundColor(RakuTheme.Color.bg)
                            .textSelection(.enabled)
                    } else {
                        Text(LocalizedStringKey(content))
                            .font(RakuTheme.Font.body())
                            .foregroundColor(RakuTheme.Color.fg)
                            .textSelection(.enabled)
                    }

                case .code(let code, let lang, _):
                    CodeBlockView(code: code, language: lang)
                }
            }
        }
    }

    private func parseSegments(_ raw: String) -> [MessageSegment] {
        var results: [MessageSegment] = []
        let parts = raw.components(separatedBy: "```")

        for (index, part) in parts.enumerated() {
            let uniqueId = "\(index)-\(part.prefix(10).hashValue)"
            if index % 2 == 0 {
                // Regular text segment
                let trimmed = part.trimmingCharacters(in: .newlines)
                if !trimmed.isEmpty {
                    results.append(.text(content: trimmed, id: uniqueId))
                }
            } else {
                // Code block segment
                var lines = part.components(separatedBy: "\n")
                var language = "code"
                if let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines), !firstLine.isEmpty {
                    language = firstLine.lowercased()
                    lines.removeFirst()
                }
                let codeContent = lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
                results.append(.code(content: codeContent, language: language, id: uniqueId))
            }
        }

        if results.isEmpty {
            results.append(.text(content: raw, id: "raw-default"))
        }

        return results
    }
}

public struct CodeBlockView: View {
    public let code: String
    public let language: String
    @State private var isCopied: Bool = false

    public init(code: String, language: String) {
        self.code = code
        self.language = language
    }

    private var lineCount: Int {
        code.components(separatedBy: "\n").count
    }

    private var badgeColor: Color {
        switch language.lowercased() {
        case "swift": return Color.orange
        case "python", "py": return Color.yellow
        case "javascript", "js", "typescript", "ts": return Color.cyan
        case "rust", "rs": return Color.brown
        case "go", "golang": return Color.teal
        case "c", "cpp", "c++", "csharp", "cs": return Color.blue
        case "html", "css": return Color.pink
        case "json", "yaml", "yml": return RakuTheme.Color.ok
        case "bash", "sh", "zsh", "shell": return Color.green
        case "sql": return Color.indigo
        default: return RakuTheme.Color.accent
        }
    }

    private var iconName: String {
        switch language.lowercased() {
        case "swift": return "swift"
        case "python", "py": return "terminal"
        case "javascript", "js", "typescript", "ts": return "curlybraces"
        case "rust", "rs": return "gearshape"
        case "go", "golang": return "paperplane.fill"
        case "c", "cpp", "c++": return "c.circle"
        case "html", "css": return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml": return "list.bullet.indent"
        case "bash", "sh", "zsh", "shell": return "terminal.fill"
        case "sql": return "cylinder.fill"
        default: return "chevron.left.forwardslash.chevron.right"
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar with language, icon, line count, and Copy button
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: iconName)
                        .font(.system(size: 11))
                        .foregroundColor(badgeColor)
                    Text(language.isEmpty ? "CODE" : language.uppercased())
                        .font(RakuTheme.Font.footnote())
                        .fontWeight(.bold)
                        .foregroundColor(badgeColor)
                }

                Text("•")
                    .foregroundColor(RakuTheme.Color.subtle)
                    .font(.system(size: 10))

                Text("\(lineCount) lines")
                    .font(RakuTheme.Font.footnote())
                    .foregroundColor(RakuTheme.Color.subtle)

                Spacer()

                Button(action: {
                    UIPasteboard.general.string = code
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isCopied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(isCopied ? "Copied" : "Copy Code")
                            .font(RakuTheme.Font.footnote())
                            .fontWeight(.medium)
                    }
                    .foregroundColor(isCopied ? RakuTheme.Color.ok : RakuTheme.Color.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RakuTheme.Color.canvas)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isCopied ? RakuTheme.Color.ok.opacity(0.5) : RakuTheme.Color.line, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RakuTheme.Color.elevated)

            Divider().overlay(RakuTheme.Color.line)

            // Monospaced Code content with horizontal scroll
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(RakuTheme.Font.code(size: 12))
                    .foregroundColor(RakuTheme.Color.fg)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(RakuTheme.Color.canvas)
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(RakuTheme.Color.line, lineWidth: 1)
        )
    }
}
