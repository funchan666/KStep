import SwiftUI

// System faces carry Korean, Japanese and Arabic without bundled fonts and follow Dynamic Type.
// Display type uses the expanded black cut: the countdown dancers shout before the music starts.
extension Font {
    static func stage(_ style: Font.TextStyle, weight: Font.Weight = .regular, display: Bool = false) -> Font {
        if display { return .system(style, design: .default, weight: .black).width(.expanded) }
        return .system(style, design: .default, weight: style == .headline && weight == .regular ? .semibold : weight)
    }
}
