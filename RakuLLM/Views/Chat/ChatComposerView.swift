import SwiftUI

public struct ChatComposerView: View {
    @Binding public var text: String
    public let isGenerating: Bool
    @Binding public var permissionMode: ToolPermissionMode
    @Binding public var isWebSearchEnabled: Bool
    @Binding public var isProductionCodeEnabled: Bool
    public let serverCount: Int
    public let toolCount: Int
    public let onSend: () -> Void
    public let onStop: () -> Void

    public init(
        text: Binding<String>,
        isGenerating: Bool,
        permissionMode: Binding<ToolPermissionMode>,
        isWebSearchEnabled: Binding<Bool>,
        isProductionCodeEnabled: Binding<Bool>,
        serverCount: Int,
        toolCount: Int,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self._text = text
        self.isGenerating = isGenerating
        self._permissionMode = permissionMode
        self._isWebSearchEnabled = isWebSearchEnabled
        self._isProductionCodeEnabled = isProductionCodeEnabled
        self.serverCount = serverCount
        self.toolCount = toolCount
        self.onSend = onSend
        self.onStop = onStop
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Controls row above input: Permissions & Mode Status Indicators
            HStack(spacing: 8) {
                PermissionDropdownView(
                    currentMode: $permissionMode,
                    serverCount: serverCount,
                    toolCount: toolCount
                )

                Spacer()

                // Web Search Status Pill
                Button(action: { isWebSearchEnabled.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isWebSearchEnabled ? "globe.americas.fill" : "globe")
                            .font(.system(size: 11))
                        Text(isWebSearchEnabled ? "Web Search ON" : "Web Search")
                            .font(RakuTheme.Font.footnote())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isWebSearchEnabled ? RakuTheme.Color.accent : RakuTheme.Color.canvas)
                    .foregroundColor(isWebSearchEnabled ? RakuTheme.Color.bg : RakuTheme.Color.subtle)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isWebSearchEnabled ? Color.clear : RakuTheme.Color.line, lineWidth: 1)
                    )
                }

                // Production Code Status Pill
                Button(action: { isProductionCodeEnabled.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isProductionCodeEnabled ? "checkmark.seal.fill" : "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11))
                        Text(isProductionCodeEnabled ? "Prod Code ON" : "Prod Code")
                            .font(RakuTheme.Font.footnote())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isProductionCodeEnabled ? RakuTheme.Color.ok : RakuTheme.Color.canvas)
                    .foregroundColor(isProductionCodeEnabled ? RakuTheme.Color.bg : RakuTheme.Color.subtle)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isProductionCodeEnabled ? Color.clear : RakuTheme.Color.line, lineWidth: 1)
                    )
                }
            }

            // Input field & Action Buttons
            HStack(alignment: .bottom, spacing: 6) {
                // Live Web Search quick toggle next to chat input
                Button(action: { isWebSearchEnabled.toggle() }) {
                    Image(systemName: isWebSearchEnabled ? "globe.americas.fill" : "globe")
                        .font(.system(size: 18))
                        .foregroundColor(isWebSearchEnabled ? RakuTheme.Color.accent : RakuTheme.Color.subtle)
                        .frame(width: 36, height: 36)
                        .background(isWebSearchEnabled ? RakuTheme.Color.accent.opacity(0.15) : RakuTheme.Color.canvas)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isWebSearchEnabled ? RakuTheme.Color.accent : RakuTheme.Color.line, lineWidth: 1))
                }

                // Production Code quick toggle beside web search
                Button(action: { isProductionCodeEnabled.toggle() }) {
                    Image(systemName: isProductionCodeEnabled ? "checkmark.seal.fill" : "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 15))
                        .foregroundColor(isProductionCodeEnabled ? RakuTheme.Color.ok : RakuTheme.Color.subtle)
                        .frame(width: 36, height: 36)
                        .background(isProductionCodeEnabled ? RakuTheme.Color.ok.opacity(0.15) : RakuTheme.Color.canvas)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isProductionCodeEnabled ? RakuTheme.Color.ok : RakuTheme.Color.line, lineWidth: 1))
                }

                // Text field
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

                // Send / Stop button
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
