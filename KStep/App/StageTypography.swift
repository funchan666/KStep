import SwiftUI

// Standard-width headlines keep their word shapes across languages and Dynamic Type sizes.
extension Font {
    static func stage(_ style: Font.TextStyle, weight: Font.Weight = .regular, display: Bool = false) -> Font {
        if display { return .system(style, design: .default, weight: weight == .regular ? .bold : weight) }
        return .system(style, design: .default, weight: style == .headline && weight == .regular ? .semibold : weight)
    }
}
