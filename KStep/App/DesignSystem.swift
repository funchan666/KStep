import SwiftUI
import UIKit

// KStep palette: an after-hours practice room. Plum walls, a blush mirror light and a
// light-stick pink for the one action that matters on each screen.
enum KStepStyle {
    static let background = Color(red: 0.090, green: 0.051, blue: 0.141)    // #170D24
    static let surface = Color(red: 0.141, green: 0.086, blue: 0.227)       // #24163A
    static let raised = Color(red: 0.200, green: 0.133, blue: 0.310)        // #33224F
    static let accent = Color(red: 1.000, green: 0.373, blue: 0.635)        // #FF5FA2
    static let ink = Color(red: 0.102, green: 0.059, blue: 0.157)           // #1A0F28
    static let secondary = Color(red: 0.718, green: 0.651, blue: 0.827)     // #B7A6D3
    static let paper = Color(red: 1.000, green: 0.937, blue: 0.961)         // #FFEFF5
    static let paperSecondary = Color(red: 0.420, green: 0.345, blue: 0.498) // #6B587F
    static let mist = Color(red: 0.902, green: 0.851, blue: 0.957)          // #E6D9F4
    static let line = Color.white.opacity(0.10)
    static let danger = Color(red: 1.000, green: 0.541, blue: 0.541)        // #FF8A8A
}

// MARK: - Original raster artwork (Asset Catalog). Missing art never blocks layout or touch.

enum ArtworkCatalog {
    private static var cache: [String: Bool] = [:]
    static func has(_ name: String) -> Bool {
        if let known = cache[name] { return known }
        let found = UIImage(named: name) != nil
        cache[name] = found
        return found
    }
}

/// Square spot illustrations for empty states, sheets and cards.
struct StageArtwork: View {
    enum Kind: String { case studio = "ArtStudio", lesson = "ArtLesson", pass = "ArtPass", notebook = "ArtNotebook" }
    let kind: Kind
    var height: CGFloat = 160
    var body: some View {
        Group {
            if ArtworkCatalog.has(kind.rawValue) {
                Image(kind.rawValue).renderingMode(.original).resizable().interpolation(.high).scaledToFit()
            } else { Color.clear }
        }
        .frame(width: height, height: height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Editorial covers for the dance guide and the practice tools.
struct GuideArtwork: View {
    enum Subject: String {
        case counts = "GuideCounts", mirror = "GuideMirror", chunk = "GuideChunk"
        case point = "GuidePoint", warmup = "GuideWarmup", stage = "GuideStage"
        case review = "ToolReview", speed = "ToolSpeed", frame = "ToolFrame", audio = "ToolAudio"
    }
    let subject: Subject
    var body: some View {
        KStepStyle.raised.overlay {
            if ArtworkCatalog.has(subject.rawValue) {
                Image(subject.rawValue).renderingMode(.original).resizable().interpolation(.high).scaledToFill()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Lets the photo scroll from the screen edge while the controls start below the status area.
struct StageScrollView<Content: View>: View {
    @ViewBuilder let content: (CGFloat) -> Content

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                content(viewport.safeAreaInsets.top)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
    }
}

struct StagePhotoHeader<Content: View>: View {
    let artwork: String
    let height: CGFloat
    var topInset: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, minHeight: height, alignment: .bottomLeading)
            .padding(.top, topInset)
            .foregroundStyle(KStepStyle.paper)
            .background { StagePhoto(artwork: artwork) }
    }
}

struct StagePhoto: View {
    let artwork: String
    var imageAlignment: Alignment = .center

    var body: some View {
        GeometryReader { frame in
            ZStack {
                KStepStyle.background
                if ArtworkCatalog.has(artwork) {
                    Image(artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: frame.size.width, height: frame.size.height, alignment: imageAlignment)
                        .clipped()
                }
                LinearGradient(stops: [
                    .init(color: KStepStyle.background.opacity(0.56), location: 0),
                    .init(color: KStepStyle.background.opacity(0.06), location: 0.33),
                    .init(color: KStepStyle.background.opacity(0.66), location: 0.73),
                    .init(color: KStepStyle.background, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Signature element: one bar of choreography, counted 1 to 8.
struct EightCountRail: View {
    var highlighted: Set<Int> = []
    var selected: Int? = nil
    var compact = false
    var select: ((Int) -> Void)? = nil
    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ForEach(1...8, id: \.self) { count in
                let on = selected == count || highlighted.contains(count)
                let cell = Text(verbatim: "\(count)")
                    .font(.stage(compact ? .caption : .subheadline, weight: .bold)).monospacedDigit()
                    .frame(maxWidth: .infinity, minHeight: compact ? 26 : 44)
                    .foregroundStyle(on ? KStepStyle.ink : KStepStyle.paper)
                    .background(on ? KStepStyle.accent : KStepStyle.paper.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: compact ? 7 : 12, style: .continuous))
                if let select {
                    Button { select(count) } label: { cell.contentShape(Rectangle()) }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(LocalizedStringKey("Eight-count beat \(count)"))
                        .accessibilityAddTraits(selected == count ? .isSelected : [])
                } else { cell }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: select == nil ? .ignore : .contain)
    }
}

// MARK: - Glyphs

enum KStepGlyph: String, CaseIterable {
    case home, feed, edit, library, link, search, bookmark, download
    case play, pause, close, back, sound, mute, folder, settings
    var assetName: String { "Glyph" + rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    // Shown only while the original glyph artwork is missing, so every control stays usable.
    var fallbackTitle: String {
        switch self {
        case .home: "Home"; case .feed: "Watch"; case .edit: "Edit"; case .library: "Library"
        case .link: "Link"; case .search: "Search"; case .bookmark: "Saved"; case .download: "Download"
        case .play: "Play"; case .pause: "Pause"; case .close: "Close"; case .back: "Back"
        case .sound: "Sound"; case .mute: "Mute"; case .folder: "Folder"; case .settings: "Me"
        }
    }
}

/// Single-colour original glyph artwork, tinted at display time.
struct Glyph: View {
    @Environment(\.layoutDirection) private var direction
    let symbol: KStepGlyph
    var size: CGFloat = 25
    var tint: Color = .white
    var body: some View {
        Group {
            if ArtworkCatalog.has(symbol.assetName) {
                Image(symbol.assetName).renderingMode(.template).resizable().interpolation(.high).scaledToFit()
                    .foregroundStyle(tint)
                    .scaleEffect(x: symbol == .back && direction == .rightToLeft ? -1 : 1, y: 1)
            } else { Color.clear }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Template artwork by asset name (player rail, tab-like controls).
struct TintedArtwork: View {
    let name: String
    var tint: Color = .white
    var body: some View {
        if ArtworkCatalog.has(name) {
            Image(name).renderingMode(.template).resizable().interpolation(.high).scaledToFit()
                .foregroundStyle(tint).allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

struct IconButton: View {
    let symbol: KStepGlyph
    let label: String
    var selected = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if ArtworkCatalog.has(symbol.assetName) {
                    Glyph(symbol: symbol, size: 21, tint: selected ? KStepStyle.accent : .white)
                } else {
                    LocalizedText(symbol.fallbackTitle).font(.stage(.caption2, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 4)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .background { if selected { StageSurface(tone: .plum) } }
            .contentShape(.interaction, Rectangle())
        }.buttonStyle(PressStyle()).accessibilityLabel(LocalizedStringKey(label))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Controls

struct PressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(!isEnabled ? 0.55 : (configuration.isPressed ? 0.7 : 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
// Compact controls keep their full localized label; enclosing layouts scroll or use ViewThatFits.
struct CompactActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.stage(.footnote, weight: .semibold))
            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 16).frame(minHeight: 44)
            .foregroundStyle(KStepStyle.paper)
            .background { StageSurface(tone: .plum) }
            .contentShape(.interaction, Rectangle())
            .opacity(!isEnabled ? 0.55 : (configuration.isPressed ? 0.7 : 1))
    }
}
struct ActionButton: View {
    let title: String
    var primary = true
    var busy = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            LocalizedText(busy ? "Please wait…" : title).font(.stage(.subheadline, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center).padding(.horizontal, 16).padding(.vertical, 12)
                .foregroundStyle(primary ? KStepStyle.ink : KStepStyle.paper)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background { StageSurface(tone: primary ? .accent : .plum) }
                .contentShape(.interaction, Rectangle())
        }.buttonStyle(PressStyle()).disabled(busy)
    }
}
struct MessagePanel: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LocalizedText(title).font(.stage(.headline)).foregroundStyle(KStepStyle.paper)
            LocalizedText(message).font(.stage(.subheadline)).foregroundStyle(KStepStyle.secondary).fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action { ActionButton(title: actionTitle, primary: false, action: action) }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(KStepStyle.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
struct ErrorNote: View {
    @Environment(\.locale) private var locale
    let message: String
    var body: some View {
        LocalizedText(message).font(.stage(.subheadline)).foregroundStyle(KStepStyle.danger)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            .accessibilityLabel(Text(verbatim: L10n.display("Error: \(message)", language: AppLanguage.from(locale))))
    }
}
struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.stage(.subheadline)).foregroundStyle(KStepStyle.paper).padding(14)
            .background(KStepStyle.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .tint(KStepStyle.accent)
    }
}
// Measure in the owning screen, so scrolling, keyboard avoidance and resizing
// keep the input exclusion region aligned. No global window or focus broadcast.
private struct KeyboardInputBounds: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $0.union($1) })
    }
}
private struct OutsideInputTap: ViewModifier {
    let focus: FocusState<Bool>.Binding
    let scope: String
    @State private var inputBounds: CGRect?
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle()) // Hit area only.
            .simultaneousGesture(SpatialTapGesture(coordinateSpace: .named(scope)).onEnded { tap in
                guard focus.wrappedValue, let inputBounds, !inputBounds.contains(tap.location) else { return }
                focus.wrappedValue = false
            })
            .onPreferenceChange(KeyboardInputBounds.self) { inputBounds = $0[scope] }
            .coordinateSpace(name: scope)
    }
}

extension View {
    func keyboardInputRegion(_ scope: String) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(key: KeyboardInputBounds.self,
                                       value: [scope: geometry.frame(in: .named(scope))])
            }.allowsHitTesting(false)
        }
    }
    func dismissKeyboardOnOutsideTap(_ focus: FocusState<Bool>.Binding, scope: String) -> some View {
        modifier(OutsideInputTap(focus: focus, scope: scope))
    }
    func kstepField() -> some View { modifier(FieldStyle()) }
    // Extend visual surfaces to every container edge, while preserving keyboard avoidance
    // and the foreground's safe area for interactive controls.
    func kstepScreenBackground(_ color: Color = KStepStyle.background) -> some View {
        background { color.ignoresSafeArea(.container, edges: .all) }
    }
    @ViewBuilder
    func stageGlass(_ shape: some Shape, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(KStepStyle.ink.opacity(0.48)).interactive(interactive), in: shape)
        } else {
            background(KStepStyle.ink.opacity(0.62), in: shape)
                .background(.regularMaterial, in: shape)
        }
    }
    // A readable column follows the available container (outer or inner display) without resetting state.
    func kstepPage(top: CGFloat = 16) -> some View {
        stageColumn().padding(.top, top).padding(.bottom, 24)
    }
    func stageColumn() -> some View {
        pageHorizontalMargins().frame(maxWidth: 680).frame(maxWidth: .infinity, alignment: .top)
    }
    @ViewBuilder
    fileprivate func pageHorizontalMargins() -> some View {
        if #available(iOS 27.1, *) {
            contentMargins(for: .container, edges: .horizontal)
        } else {
            padding(.horizontal, 20)
        }
    }
}

struct MediaCover: View {
    let url: URL?
    var folder = false
    var body: some View {
        KStepStyle.raised.overlay {
            GeometryReader { geometry in
                Group {
                    if folder { Glyph(symbol: .folder, size: 30) }
                    else if let url {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() }
                            else { Glyph(symbol: .feed, size: 30) }
                        }
                    } else { Glyph(symbol: .feed, size: 30) }
                }.frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
        }.clipped()
    }
}
struct SheetHeading: View {
    let title: String
    var close: () -> Void
    var body: some View {
        HStack {
            LocalizedText(title).font(.stage(.headline)).lineLimit(2)
            Spacer()
            IconButton(symbol: .close, label: "Close", action: close)
        }.pageHorizontalMargins().padding(.top, 8)
    }
}

struct SectionLabel: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                LocalizedText(title).font(.stage(.headline))
                Spacer(minLength: 12)
                if let detail { LocalizedText(detail).font(.stage(.caption)).foregroundStyle(KStepStyle.secondary) }
            }
            VStack(alignment: .leading, spacing: 6) {
                LocalizedText(title).font(.stage(.headline))
                if let detail { LocalizedText(detail).font(.stage(.caption)).foregroundStyle(KStepStyle.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// Original raster artwork. Its layout never participates in navigation hit testing.
struct KStepIllustration: View {
    let name: String
    var height: CGFloat = 180
    var body: some View {
        Group {
            if ArtworkCatalog.has(name) {
                Image(name).renderingMode(.original).resizable().scaledToFit()
            } else { Color.clear }
        }
        .frame(maxWidth: .infinity).frame(height: height)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct FeatureRow: View {
    let symbol: KStepGlyph
    let title: String
    let detail: String
    var body: some View {
        HStack(spacing: 16) {
            Glyph(symbol: symbol, size: 22)
                .frame(width: 48, height: 48)
                .background(KStepStyle.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                LocalizedText(title).font(.stage(.subheadline, weight: .semibold)).foregroundStyle(KStepStyle.paper)
                LocalizedText(detail).font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Surfaces (native fills; no drawn artwork)

struct StageSurface: View {
    enum Tone { case accent, plum, blush, mist }
    let tone: Tone
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        switch tone {
        case .accent: shape.fill(KStepStyle.accent)
        case .plum: shape.fill(KStepStyle.raised).overlay(shape.strokeBorder(KStepStyle.line))
        case .blush: shape.fill(KStepStyle.paper)
        case .mist: shape.fill(KStepStyle.surface).overlay(shape.strokeBorder(KStepStyle.line))
        }
    }
}

/// Surfaces for controls placed on the blush paper card.
struct PaperSurface: View {
    enum Tone { case accent, plum, inkOnPaper, mistOnPaper }
    let tone: Tone
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        switch tone {
        case .accent: shape.fill(KStepStyle.accent)
        case .plum: shape.fill(KStepStyle.raised)
        case .inkOnPaper: shape.fill(KStepStyle.ink)
        case .mistOnPaper: shape.fill(KStepStyle.mist)
        }
    }
}

struct MatteActionStyle: ButtonStyle {
    var onPaper = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.stage(.footnote, weight: .semibold))
            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 44)
            .foregroundStyle(onPaper ? KStepStyle.ink : KStepStyle.paper)
            .background { PaperSurface(tone: onPaper ? .mistOnPaper : .plum) }
            .contentShape(Rectangle())
            .opacity(!isEnabled ? 0.55 : (configuration.isPressed ? 0.75 : 1))
    }
}

struct ChoiceStrip: View {
    let values: [String]
    let selected: String
    let select: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button { select(value) } label: {
                        LocalizedText(value).font(.stage(.footnote, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .frame(minHeight: 44)
                            .foregroundStyle(selected == value ? KStepStyle.ink : KStepStyle.paper)
                            .background { StageSurface(tone: selected == value ? .accent : .plum) }
                            .contentShape(Rectangle())
                    }.buttonStyle(PressStyle())
                        .accessibilityAddTraits(selected == value ? .isSelected : [])
                }
            }
        }
    }
}
