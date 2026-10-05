import SwiftUI

public struct PermissionDropdownView: View {
    @Binding public var currentMode: ToolPermissionMode
    public let serverCount: Int
    public let toolCount: Int

    public init(
        currentMode: Binding<ToolPermissionMode>,
        serverCount: Int,
        toolCount: Int
    ) {
        self._currentMode = currentMode
        self.serverCount = serverCount
        self.toolCount = toolCount
    }

    public var body: some View {
        Menu {
            ForEach(ToolPermissionMode.allCases) { mode in
                Button(action: {
                    currentMode = mode
                }) {
                    HStack {
                        Text(mode.displayName)
                        if currentMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: iconName(for: currentMode))
                    .font(.system(size: 11))
                Text("\(currentMode.displayName) (\(serverCount)s / \(toolCount)t)")
                    .font(RakuTheme.Font.footnote())
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(RakuTheme.Color.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RakuTheme.Color.elevated)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(RakuTheme.Color.line, lineWidth: 0.5)
            )
        }
    }

    private func iconName(for mode: ToolPermissionMode) -> String {
        switch mode {
        case .inherit: return "arrow.triangle.branch"
        case .allowAll: return "checkmark.shield.fill"
        case .confirmEach: return "questionmark.shield"
        case .allowlist: return "list.bullet.rectangle"
        }
    }
}
