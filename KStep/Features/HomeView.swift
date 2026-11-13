import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var commerce: CommerceStore
    @EnvironmentObject private var quota: QuotaStore
    var openAccount: () -> Void
    var discover: () -> Void
    var openTools: () -> Void
    @Binding var link: String
    @Binding var revealLinkComposer: Bool
    @State private var error: String?
    @State private var pasteError = false
    @State private var showingConnectionFailure = false
    @State private var channel: ChannelRoute?
    @State private var searchRequest: LessonSearch?
    @State private var paywall = false
    @State private var channels: [LandingInfo] = []
    @State private var channelRetry = 0
    @State private var showingLinkGuide = false
    @State private var showingGuide = false
    @State private var showingPractice = false
    @State private var composerWidth: CGFloat = 0
    @SceneStorage("rehearsal.beat") private var beat = 1
    @SceneStorage("rehearsal.tempo") private var tempo = PracticeTempo.threeQuarters
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .subheadline) private var minimumInlineWidth: CGFloat = 230
    @ScaledMetric(relativeTo: .footnote) private var inlineTempoWidth: CGFloat = 48
    private let pasteErrorMessage = "Copy a lesson link or code, then tap Paste."

    var body: some View {
        let request = ChannelRequest(links: commerce.release?.lcList?["us"] ?? [], attempt: channelRetry)
        ScrollViewReader { scroll in
            GeometryReader { viewport in
                let artworkHeight = min(max(viewport.size.width * 0.80, 212), 336)
                StageScrollView { topInset in
                    VStack(spacing: 0) {
                        rehearsalHeader(topInset: topInset, artworkHeight: artworkHeight)
                        VStack(alignment: .leading, spacing: 22) {
                            linkComposer.id("lesson-link-composer")
                            connection
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 10) { lessonActions }
                                VStack(spacing: 10) { lessonActions }
                            }
                            choreoCollections
                            DanceGuideEntry(compact: true) { showingGuide = true }
                            recentLinks
                        }.kstepPage(top: 18)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnOutsideTap($focused, scope: "home-link-input")
            }
            .onChange(of: revealLinkComposer, initial: true) { _, requested in
                guard requested else { return }
                scroll.scrollTo("lesson-link-composer")
                revealLinkComposer = false
            }
        }.kstepScreenBackground().foregroundStyle(KStepStyle.paper)
            .onChange(of: link) { _, _ in pasteError = false }
            .sheet(item: $channel) { ChannelView(route: $0) }
            .fullScreenCover(item: $searchRequest) { request in
                DiscoverView(initialSearch: request.query, canDismiss: true, onSearchResult: { query, clip in
                    library.record(link: query, title: clip.title)
                })
            }
            .fullScreenCover(isPresented: $showingConnectionFailure) {
                AccountDecisionDialog(title: "Couldn’t open the lesson", message: "Check your connection and try again.",
                                      confirmTitle: "Got it") { showingConnectionFailure = false }
                    .presentationBackground(.clear)
            }
            .sheet(isPresented: $paywall) { MembershipView() }
            .sheet(isPresented: $showingLinkGuide) { LinkGuideSheet() }
            .sheet(isPresented: $showingGuide) { DanceGuideView() }
            .sheet(isPresented: $showingPractice) {
                DancePracticeView(initialEightCount: beat, initialTempo: tempo)
            }
            .task(id: request) {
                guard !Task.isCancelled else { return }
                channels = []
                error = nil
                guard !request.links.isEmpty else { return }
                do {
                    let result = try await api.channels(links: request.links)
                    if !Task.isCancelled { channels = result }
                } catch {
                    if !Task.isCancelled { self.error = error.localizedDescription }
                }
            }
    }

    private func rehearsalHeader(topInset: CGFloat, artworkHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            headerActions.stageColumn()
                .padding(.top, 6)
                .frame(minHeight: artworkHeight * 0.70, alignment: .top)
                .padding(.top, topInset)
            rehearsalPanel.stageColumn()
        }.background(alignment: .top) {
            StagePhoto(artwork: "RehearsalStudio")
                .frame(height: topInset + artworkHeight)
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button { paywall = true } label: {
                LocalizedText(commerce.premium ? "Plus" : "Get Plus")
                    .font(.stage(.footnote, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .frame(minWidth: 44, minHeight: 44)
                    .stageGlass(Capsule(), interactive: true)
                    .contentShape(Capsule())
            }.buttonStyle(PressStyle())
            IconButton(symbol: .settings, label: "Open Me and account settings", action: openAccount)
                .stageGlass(Circle(), interactive: true)
        }.frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder private var connection: some View {
        if api.session == nil { ConnectionPanel() }
        if let error {
            MessagePanel(title: "Couldn’t load lesson collections", message: error, actionTitle: "Try again") {
                channelRetry += 1
            }
        }
    }

    private var rehearsalPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            LocalizedText("Eight-count")
                .font(.stage(.title2, display: true))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .horizontal) {
                beatGrid(columns: 8)
                beatGrid(columns: 4)
                beatGrid(columns: 2)
                beatGrid(columns: 1)
            }.environment(\.layoutDirection, .leftToRight)
            practiceSpeed
            Button { showingPractice = true } label: {
                HStack(spacing: 10) {
                    Glyph(symbol: .edit, size: 18, tint: KStepStyle.accent)
                    LocalizedText("Rehearsal log")
                        .font(.stage(.subheadline, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Glyph(symbol: .back, size: 13, tint: KStepStyle.accent)
                        .rotationEffect(.degrees(180))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(KStepStyle.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }.buttonStyle(PressStyle()).accessibilityIdentifier("practice.openJournal")
        }
        .padding(14)
        .stageGlass(RoundedRectangle(cornerRadius: 22))
    }

    private func beatGrid(columns: Int) -> some View {
        let title = L10n.text("Eight-count", language: AppLanguage.from(locale))
        return Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<(8 / columns), id: \.self) { row in
                GridRow {
                    ForEach(1...columns, id: \.self) { column in
                        let count = row * columns + column
                        let selected = beat == count
                        let number = count.formatted(.number.locale(locale))
                        Button { beat = count } label: {
                            Text(verbatim: number)
                                .font(.stage(.title3, weight: .semibold))
                                .monospacedDigit()
                                .fixedSize()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(selected ? KStepStyle.ink : KStepStyle.paper)
                                .background(selected ? KStepStyle.paper : KStepStyle.paper.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 10))
                                .contentShape(Rectangle())
                        }.buttonStyle(PressStyle())
                            .accessibilityLabel(Text(verbatim: "\(title) \(number)"))
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var practiceSpeed: some View {
        let label = LocalizedText("Practice speed")
            .font(.stage(.footnote, weight: .semibold))
            .foregroundStyle(KStepStyle.secondary)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                label.fixedSize()
                tempoSelector(inline: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                label.fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    tempoSelector(inline: true)
                    tempoSelector(inline: false)
                }
            }
        }
    }

    private func tempoSelector(inline: Bool) -> some View {
        let layout = inline ? AnyLayout(HStackLayout(spacing: 2)) : AnyLayout(VStackLayout(spacing: 2))
        let minimumWidth = inline ? max(44, inlineTempoWidth) : 44
        return layout {
            ForEach(PracticeTempo.allCases) { value in
                let selected = tempo == value
                Button { tempo = value } label: {
                    LocalizedText(value.label)
                        .font(.stage(.footnote, weight: .semibold).monospacedDigit())
                        .fixedSize(horizontal: inline, vertical: true)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .frame(minWidth: minimumWidth, maxWidth: .infinity, minHeight: 44)
                        .background(selected ? KStepStyle.mist.opacity(0.32) : .clear,
                                    in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                }.buttonStyle(PressStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(KStepStyle.ink.opacity(0.30), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var choreoCollections: some View {
        if !channels.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                LocalizedText("Choreo collections").font(.stage(.title2, display: true))
                    .accessibilityAddTraits(.isHeader)
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(channels.indices, id: \.self) { index in
                            let item = channels[index]
                            if let info = item.extraInfo, let title = info.channelName, let short = info.externalLinks {
                                Button { channel = ChannelRoute(link: short, title: title) } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        MediaCover(url: WebAddress.media(item.shortCover))
                                            .frame(height: 112).clipShape(.rect(cornerRadius: 10))
                                            .accessibilityHidden(true)
                                        Text(verbatim: title).font(.stage(.headline))
                                            .fixedSize(horizontal: false, vertical: true)
                                        if let count = info.videoFileCount {
                                            LocalizedText("\(count) videos").font(.stage(.caption))
                                                .foregroundStyle(KStepStyle.secondary)
                                        }
                                    }.frame(width: typeSize.isAccessibilitySize ? 224 : 156, alignment: .leading)
                                        .contentShape(Rectangle())
                                }.buttonStyle(PressStyle())
                            }
                        }
                    }
                }.scrollIndicators(.hidden)
            }
        }
    }

    private var linkComposer: some View {
        // Change the layout without replacing the focused field.
        let stacksInput = typeSize.isAccessibilitySize || (composerWidth > 0 && composerWidth < minimumInlineWidth)
        let inputLayout = stacksInput
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return VStack(alignment: .leading, spacing: 10) {
            LocalizedText("Find a lesson")
                .font(.stage(.headline, weight: .bold))
                .foregroundStyle(KStepStyle.paper)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            inputLayout {
                lessonInput
                pasteButton
            }
            .keyboardInputRegion("home-link-input")

            if pasteError {
                LocalizedText(pasteErrorMessage)
                    .font(.stage(.footnote)).foregroundStyle(KStepStyle.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.linkError")
            }

            Button(action: resolve) {
                HStack(spacing: 8) {
                    Glyph(symbol: .play, size: 14, tint: canOpenLink ? KStepStyle.ink : KStepStyle.secondary)
                    LocalizedText("Open lesson")
                        .font(.stage(.subheadline, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(canOpenLink ? KStepStyle.ink : KStepStyle.secondary)
                .background { StageSurface(tone: canOpenLink ? .accent : .plum) }
                .contentShape(Rectangle())
            }.buttonStyle(ComposerPressStyle()).disabled(!canOpenLink)
                .accessibilityIdentifier("home.openLesson")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    allowanceLabel.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    linkHelpButton.fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 0) {
                    allowanceLabel
                    linkHelpButton
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { composerWidth = $0 }
        .padding(.top, 12)
        .overlay(alignment: .top) { Divider().overlay(KStepStyle.line).allowsHitTesting(false) }
    }

    private var lessonInput: some View {
        let prompt = Text(verbatim: L10n.text("Lesson link or short code", language: AppLanguage.from(locale)))
            .foregroundStyle(KStepStyle.secondary)
        let fieldShape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HStack(spacing: 0) {
            TextField(text: $link, prompt: prompt, axis: .vertical) {
                LocalizedText("Lesson link or short code")
            }
            .lineLimit(1...3)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focused)
            .font(.stage(.subheadline))
            .foregroundStyle(KStepStyle.paper)
            .tint(KStepStyle.accent)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
            if !link.isEmpty {
                Button {
                    link = ""
                    focused = true
                } label: {
                    Glyph(symbol: .close, size: 13, tint: KStepStyle.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }.buttonStyle(PressStyle())
                    .accessibilityLabel(LocalizedStringKey("Clear link"))
                    .accessibilityIdentifier("home.clearLink")
            }
        }.background {
            fieldShape.fill(KStepStyle.ink)
                .overlay(fieldShape.strokeBorder(focused ? KStepStyle.accent : KStepStyle.secondary.opacity(0.65)))
        }
    }

    private var canOpenLink: Bool { searchRequest == nil && link.nilIfBlank != nil }

    private var allowanceText: LocalizedText? {
        guard api.session != nil else { return nil }
        if commerce.premium || quota.unlimited { return LocalizedText("Unlimited lesson views today") }
        if quota.error != nil { return LocalizedText("Couldn’t check remaining views") }
        if quota.usage == nil { return LocalizedText("Checking remaining views…") }
        let count = quota.watchesLeft
        let key = count == 1 ? "%@ lesson view left today" : "%@ lesson views left today"
        return LocalizedText(key, count.formatted(.number.locale(locale)))
    }

    @ViewBuilder private var allowanceLabel: some View {
        if let allowanceText {
            allowanceText
                .font(.stage(.caption))
                .monospacedDigit()
                .foregroundStyle(KStepStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var linkHelpButton: some View {
        Button { showingLinkGuide = true } label: {
            LocalizedText("Link & code help")
                .font(.stage(.caption, weight: .semibold))
                .underline()
                .foregroundStyle(KStepStyle.paper)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }.buttonStyle(PressStyle())
            .accessibilityIdentifier("home.linkHelp")
    }

    private var pasteButton: some View {
        Button(action: pasteCopiedLink) {
            LocalizedText("Paste").font(.stage(.footnote, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(minWidth: 44, minHeight: 48)
                .multilineTextAlignment(.center)
                .foregroundStyle(KStepStyle.paper)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(KStepStyle.secondary.opacity(0.65))
                }
                .contentShape(Rectangle())
        }.buttonStyle(PressStyle())
            .accessibilityIdentifier("home.pasteLink")
    }

    private func pasteCopiedLink() {
        guard let text = UIPasteboard.general.string, text.nilIfBlank != nil else {
            pasteError = true
            UIAccessibility.post(notification: .announcement,
                                 argument: L10n.text(pasteErrorMessage, language: AppLanguage.from(locale)))
            return
        }
        pasteError = false
        link = text
    }
    @ViewBuilder private var recentLinks: some View {
        if !library.history.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    LocalizedText("Recently opened").font(.stage(.headline))
                    Spacer()
                    Button("Clear") { library.clearHistory() }
                        .buttonStyle(MatteActionStyle())
                }
                ForEach(library.history.prefix(5)) { visit in
                    HStack {
                        Button { link = visit.link; resolve() } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(verbatim: visit.title).font(.stage(.headline)).lineLimit(1)
                                Text(verbatim: visit.link).font(.stage(.caption)).foregroundStyle(KStepStyle.secondary).lineLimit(1)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }.buttonStyle(PressStyle()).disabled(searchRequest != nil)
                        IconButton(symbol: .close, label: "Remove history item") { library.removeVisit(visit) }
                    }
                }
            }
        }
    }
    @ViewBuilder private var lessonActions: some View {
        lessonAction(.feed, title: "Browse lessons", action: discover)
        lessonAction(.edit, title: "Review video", action: openTools)
    }

    private func lessonAction(_ symbol: KStepGlyph, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Glyph(symbol: symbol, size: 17, tint: KStepStyle.secondary)
                LocalizedText(title).font(.stage(.subheadline, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(12).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .foregroundStyle(KStepStyle.paper)
                .background { StageSurface(tone: .mist) }
                .contentShape(Rectangle())
        }.buttonStyle(PressStyle())
    }
    private func resolve() {
        guard let text = link.nilIfBlank, searchRequest == nil else { return }
        focused = false
        guard api.session != nil else { showingConnectionFailure = true; return }
        pasteError = false
        // Preserve exactly what was entered. Search owns loading, errors and cursor
        // pagination; do not fall back to the old landing-page resolver.
        searchRequest = LessonSearch(query: text)
    }
}

// The lesson action supplies its own disabled colors.
private struct ComposerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct LessonSearch: Identifiable {
    let id = UUID()
    let query: String
}

private struct ChannelRequest: Equatable {
    let links: [String]
    let attempt: Int
}

struct ChannelView: View {
    @EnvironmentObject private var api: APIClient
    @Environment(\.dismiss) private var dismiss
    let route: ChannelRoute
    @State private var items: [RemoteLessonFile] = []
    @State private var page = 1
    @State private var hasMore = true
    @State private var loading = false
    @State private var error: String?
    @State private var child: ChannelRoute?
    @State private var player: PlayerRoute?
    var body: some View {
        VStack(spacing: 0) {
            SheetHeading(title: route.title) { dismiss() }
            ScrollView {
                LazyVStack(spacing: 18) {
                    StageArtwork(kind: .notebook, height: 140)
                    if items.isEmpty, !loading, error == nil { MessagePanel(title: "Nothing here yet", message: "This channel has no available videos.") }
                    ForEach(items, id: \.stableID) { item in
                        Button { open(item) } label: {
                            HStack(spacing: 16) {
                                MediaCover(url: WebAddress.media(item.coverImage), folder: item.isFolder == true)
                                    .frame(width: 80, height: 94).clipShape(RoundedRectangle(cornerRadius: 14))
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(verbatim: item.name ?? L10n.text("Untitled")).font(.stage(.headline)).lineLimit(3)
                                    LocalizedText(item.isFolder == true ? "\(item.childrenFileNum ?? 0) videos" : durationLabel(item.length ?? 0))
                                        .font(.caption.monospacedDigit()).foregroundStyle(KStepStyle.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Glyph(symbol: item.isFolder == true ? .folder : .play, size: 20)
                            }
                        }.buttonStyle(PressStyle())
                    }
                    if let error { ErrorNote(message: error) }
                    if hasMore { ActionButton(title: error == nil ? "Load more" : "Try again", primary: false, busy: loading) { Task { await load() } } }
                }.padding(22)
            }
        }.kstepScreenBackground().foregroundStyle(.white)
            .task { if items.isEmpty { await load() } }
            .sheet(item: $child) { ChannelView(route: $0) }
            .fullScreenCover(item: $player) { PlayerScreen(route: $0) }
    }
    private func load() async {
        guard !loading, hasMore else { return }
        loading = true
        error = nil
        defer { loading = false }
        do {
            let result = try await api.channelPage(link: route.link, page: page)
            var seen = Set(items.map(\.stableID))
            items += result.list.filter { $0.name?.nilIfBlank != nil && !$0.stableID.isEmpty && seen.insert($0.stableID).inserted }
            hasMore = page * 20 < result.total && !result.list.isEmpty
            page += 1
        } catch { self.error = error.localizedDescription }
    }
    private func open(_ item: RemoteLessonFile) {
        if item.isFolder == true, let link = item.landingPage?.nilIfBlank {
            child = ChannelRoute(link: link, title: item.name ?? "Folder")
        } else if let clip = item.clip(channel: route.title) {
            player = PlayerRoute(clips: items.compactMap { $0.clip(channel: route.title) }, startID: clip.id, continuesRecommendations: true)
        } else { error = "This item does not contain a playable video." }
    }
}

struct LinkGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            SheetHeading(title: "Lesson links and codes") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(symbol: .link, title: "Paste a link or enter a code",
                               detail: "Enter the code exactly as shared, including capital letters.")
                    FeatureRow(symbol: .play, title: "Open lesson", detail: "Swipe up or down to change videos")
                    ActionButton(title: "Got it") { dismiss() }
                }.kstepPage()
            }
        }.kstepScreenBackground().foregroundStyle(.white)
    }
}
