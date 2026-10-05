import SwiftUI

public struct ChatComposerView: View {
    @Binding public var text: String
    public let isGenerating: Bool
    @Binding public var permissionMode: ToolPermissionMode
    public let serverCount: Int
    public let toolCount: Int
    public let onSend: () -> Void
    public let onStop: () -> Void

    public init(
        text: Binding<String>,
        isGenerating: Bool,
        permissionMode: Binding<ToolPermissionMode>,
        serverCount: Int,
        toolCount: Int,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self._text = text
        self.isGenerating = isGenerating
        self._permissionMode = permissionMode
        self.serverCount = serverCount
        self.toolCount = toolCount
        self.onSend = onSend
        self.onStop = onStop
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Controls row above input
            HStack {
                PermissionDropdownView(
                    currentMode: $permissionMode,
                    serverCount: serverCount,
                    toolCount: toolCount
                )
                Spacer()
            }

            // Input field & Send button
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message RakuLLM...", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .font(RakuTheme.Font.body())
                    .foregroundColor(RakuTheme.Color.fg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RakuTheme.Color.canvas)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(RakuTheme.Color.line, lineWidth: 1)
                    )

                if isGenerating {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(RakuTheme.Color.danger)
                    }
                } else {
                    Button(action: {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            onSend()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? RakuTheme.Color.subtle : RakuTheme.Color.ok)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RakuTheme.Color.elevated)
    }
}
