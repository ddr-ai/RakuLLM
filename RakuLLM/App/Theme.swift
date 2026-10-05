import SwiftUI

public enum RakuTheme {
    public enum Color {
        public static let canvas = SwiftUI.Color(red: 7 / 255, green: 7 / 255, blue: 8 / 255)
        public static let bg = SwiftUI.Color(red: 11 / 255, green: 12 / 255, blue: 14 / 255)
        public static let elevated = SwiftUI.Color(red: 22 / 255, green: 23 / 255, blue: 26 / 255)
        public static let fg = SwiftUI.Color(red: 232 / 255, green: 226 / 255, blue: 214 / 255)
        public static let muted = SwiftUI.Color(red: 163 / 255, green: 158 / 255, blue: 148 / 255)
        public static let subtle = SwiftUI.Color(red: 111 / 255, green: 106 / 255, blue: 98 / 255)
        public static let line = SwiftUI.Color(red: 44 / 255, green: 43 / 255, blue: 40 / 255)
        public static let ok = SwiftUI.Color(red: 126 / 255, green: 168 / 255, blue: 146 / 255)
        public static let danger = SwiftUI.Color(red: 196 / 255, green: 107 / 255, blue: 90 / 255)
        public static let warning = SwiftUI.Color(red: 224 / 255, green: 175 / 255, blue: 104 / 255)
        public static let accent = SwiftUI.Color(red: 126 / 255, green: 168 / 255, blue: 146 / 255)
    }

    public enum Font {
        public static func largeTitle() -> SwiftUI.Font {
            SwiftUI.Font.custom("AvenirNext-Bold", size: 30)
        }
        public static func title() -> SwiftUI.Font {
            SwiftUI.Font.custom("AvenirNext-DemiBold", size: 20)
        }
        public static func title2() -> SwiftUI.Font {
            SwiftUI.Font.custom("AvenirNext-DemiBold", size: 17)
        }
        public static func headline() -> SwiftUI.Font {
            SwiftUI.Font.custom("AvenirNext-Medium", size: 15)
        }
        public static func body() -> SwiftUI.Font {
            SwiftUI.Font.custom("AvenirNext-Regular", size: 15)
        }
        public static func subheadline() -> SwiftUI.Font {
            SwiftUI.Font.custom("AvenirNext-Regular", size: 13)
        }
        public static func footnote() -> SwiftUI.Font {
            SwiftUI.Font.custom("AvenirNext-Medium", size: 11)
        }
        public static func code(size: CGFloat = 13) -> SwiftUI.Font {
            SwiftUI.Font.system(size: size, weight: .regular, design: .monospaced)
        }
    }
}

public struct CardModifier: ViewModifier {
    public var padding: CGFloat = 14
    public var cornerRadius: CGFloat = 12

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RakuTheme.Color.elevated)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(RakuTheme.Color.line, lineWidth: 1)
            )
    }
}

public extension View {
    func rakuCard(padding: CGFloat = 14, cornerRadius: CGFloat = 12) -> some View {
        modifier(CardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}
