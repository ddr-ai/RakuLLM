import SwiftUI

public struct FitBadgeView: View {
    public let fitLevel: FitLevel
    public let referenceContext: Int

    public init(fitLevel: FitLevel, referenceContext: Int = 4096) {
        self.fitLevel = fitLevel
        self.referenceContext = referenceContext
    }

    private var badgeColor: SwiftUI.Color {
        switch fitLevel {
        case .fits: return RakuTheme.Color.ok
        case .tight: return RakuTheme.Color.warning
        case .tooLarge: return RakuTheme.Color.danger
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(badgeColor)
                .frame(width: 6, height: 6)
            Text(fitLevel.displayName)
                .font(RakuTheme.Font.footnote())
                .foregroundColor(RakuTheme.Color.fg)
            Text("(\(referenceContext) ctx)")
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(RakuTheme.Color.subtle)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(badgeColor.opacity(0.3), lineWidth: 1)
        )
    }
}
