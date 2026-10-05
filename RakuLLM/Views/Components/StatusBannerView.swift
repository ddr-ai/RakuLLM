import SwiftUI

public struct StatusBannerView: View {
    public let icon: String
    public let message: String
    public let color: SwiftUI.Color
    public var actionTitle: String? = nil
    public var action: (() -> Void)? = nil

    public init(
        icon: String = "info.circle",
        message: String,
        color: SwiftUI.Color = RakuTheme.Color.warning,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.message = message
        self.color = color
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(message)
                .font(RakuTheme.Font.subheadline())
                .foregroundColor(RakuTheme.Color.fg)
            Spacer()
            if let title = actionTitle, let act = action {
                Button(action: act) {
                    Text(title)
                        .font(RakuTheme.Font.footnote())
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.15))
                        .cornerRadius(6)
                }
            }
        }
        .padding(10)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}
