import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var commerce: CommerceStore
    @EnvironmentObject private var quota: QuotaStore
    var openAccount: () -> Void
    var discover: () -> Void
    var openTools: () -> Void
    @Binding var link: String
    @State private var error: String?
    @State private var linkFailure = ""
    @State private var showingLinkFailure = false
    @State private var channel: ChannelRoute?
    @State private var searchRequest: LessonSearch?
    @State private var paywall = false
    @State private var channels: [LandingInfo] = []
    @State private var channelRetry = 0
    @State private var showingLinkGuide = false
    @State private var showingGuide = false
    @State private var showingPractice = false
    @FocusState private var focused: Bool
    var body: some View {
        let request = ChannelRequest(links: commerce.release?.lcList?["us"] ?? [], attempt: channelRetry)
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 10) {
                    Text(verbatim: "KStep").font(.stage(.title3, display: true))
                        .foregroundStyle(KStepStyle.paper).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(LocalizedStringKey(commerce.premium ? "PLUS" : "Get Plus")) { paywall = true }
                        .buttonStyle(MatteActionStyle())
                    IconButton(symbol: .settings, label: "Open Me and account settings", action: openAccount)
                }
                StageBanner()
                linkComposer
                if let error {
                    MessagePanel(title: "Couldn’t load lesson collections", message: error, actionTitle: "Try again") {
                        channelRetry += 1
                    }
                }
                if api.session == nil { ConnectionPanel() }
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "From the screen to the floor")
                    DancePracticeEntry { showingPractice = true }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { lessonActions }
                        VStack(spacing: 10) { lessonActions }
                    }
                    DanceGuideEntry(compact: true) { showingGuide = true }
                }
                recentLinks
                if !channels.isEmpty {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            LocalizedText("Choreo collections").font(.stage(.headline))
                            LocalizedText("Pick a song. Learn it section by section.").font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        StageArtwork(kind: .notebook, height: 76).frame(width: 114)
                    }
                    ForEach(Array(channels.enumerated()), id: \.offset) { _, item in
                        if let info = item.extraInfo, let title = info.channelName, let short = info.externalLinks {
                            Button { channel = ChannelRoute(link: short, title: title) } label: {
                                HStack(spacing: 14) {
                                    MediaCover(url: WebAddress.media(item.shortCover), folder: false).frame(width: 62, height: 72).clipShape(RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(verbatim: title).font(.stage(.headline)).lineLimit(2)
                                        if let count = info.videoFileCount { LocalizedText("\(count) videos").font(.stage(.caption)).foregroundStyle(KStepStyle.secondary) }
                                    }
                                    Spacer()
                                }
                            }.buttonStyle(PressStyle())
                        }
                    }
                }
            }.kstepPage()
        }.kstepScreenBackground().scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnOutsideTap($focused, scope: "home-link-input")
            .sheet(item: $channel) { ChannelView(route: $0) }
            .fullScreenCover(item: $searchRequest) { request in
                DiscoverView(initialSearch: request.query, canDismiss: true) { query, clip in
                    library.record(link: query, title: clip.title)
                }
            }
            .fullScreenCover(isPresented: $showingLinkFailure) {
                AccountDecisionDialog(title: "Couldn’t open this link", message: linkFailure,
                                      confirmTitle: "Back to link", confirm: { showingLinkFailure = false })
                    .presentationBackground(.clear)
            }
            .sheet(isPresented: $paywall) { MembershipView() }
            .sheet(isPresented: $showingLinkGuide) { LinkGuideSheet() }
            .sheet(isPresented: $showingGuide) { DanceGuideView() }
            .sheet(isPresented: $showingPractice) { DancePracticeView() }
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
    private var linkComposer: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Glyph(symbol: .link, size: 20)
                    .frame(width: 40, height: 40)
                    .background(KStepStyle.ink, in: RoundedRectangle(cornerRadius: 12))
                LocalizedText("Open a dance lesson").font(.stage(.headline))
                    .foregroundStyle(KStepStyle.ink).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 0) {
                TextField("KStep link or lesson code", text: $link, axis: .vertical)
                    .lineLimit(1...3).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($focused).font(.stage(.subheadline)).foregroundStyle(KStepStyle.ink)
                    .tint(KStepStyle.ink)
                    .padding(.leading, 14).padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(LocalizedStringKey("KStep link or lesson code"))
                if !link.isEmpty {
                    Button {
                        link = ""
                        focused = true
                    } label: {
                        Glyph(symbol: .close, size: 13, tint: KStepStyle.ink.opacity(0.65))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }.buttonStyle(ComposerPressStyle())
                        .accessibilityLabel(LocalizedStringKey("Clear link"))
                        .accessibilityIdentifier("home.clearLink")
                }
            }
                // Link input and its clear action stay together, including when
                // the outside-tap handler decides whether to dismiss the keyboard.
                .padding(.trailing, link.isEmpty ? 14 : 6)
                .environment(\.layoutDirection, .leftToRight)
                .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                .environment(\.colorScheme, .light)
                .keyboardInputRegion("home-link-input")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    allowanceLabel.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 8)
                    pasteButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Spacer(minLength: 0); pasteButton }
                    allowanceLabel
                }
            }
            Button(action: resolve) {
                HStack(spacing: 10) {
                    Glyph(symbol: .play, size: 15, tint: KStepStyle.ink)
                    LocalizedText("Open lesson").font(.stage(.subheadline, weight: .bold))
                }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(KStepStyle.ink)
                    .background { PaperSurface(tone: canOpenLink ? .accent : .mistOnPaper) }
                    .contentShape(Rectangle())
            }.buttonStyle(ComposerPressStyle()).disabled(!canOpenLink)
                .accessibilityIdentifier("home.openLesson")
            HStack(alignment: .center, spacing: 12) {
                LocalizedText("Use a lesson link or code shared through KStep.")
                    .font(.stage(.caption)).foregroundStyle(KStepStyle.paperSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { showingLinkGuide = true } label: {
                    LocalizedText("How to").font(.stage(.caption, weight: .semibold))
                        .underline().foregroundStyle(KStepStyle.ink)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }.buttonStyle(ComposerPressStyle())
                    .accessibilityIdentifier("home.linkHelp")
            }
        }.padding(20).background(KStepStyle.paper, in: RoundedRectangle(cornerRadius: 26))
    }
    private var canOpenLink: Bool { searchRequest == nil && link.nilIfBlank != nil }
    @ViewBuilder private var allowanceLabel: some View {
        if api.session != nil {
            LocalizedText(quota.usage == nil ? "Loading…" : commerce.premium || quota.unlimited ? "Unlimited viewing today" : "\(quota.watchesLeft) views left today")
                .font(.stage(.caption)).foregroundStyle(KStepStyle.paperSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private var pasteButton: some View {
        Button(action: pasteCopiedLink) {
            LocalizedText("Paste").font(.stage(.footnote, weight: .semibold))
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .frame(minHeight: 44)
                .foregroundStyle(KStepStyle.paper)
                .background { PaperSurface(tone: .inkOnPaper) }
                .contentShape(Rectangle())
        }.buttonStyle(ComposerPressStyle())
            .accessibilityIdentifier("home.pasteLink")
    }
    private func pasteCopiedLink() {
        guard let text = UIPasteboard.general.string, text.nilIfBlank != nil else {
            showLinkFailure("Copy a KStep link or lesson code first, then tap Paste.")
            return
        }
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
        lessonAction(.feed, title: "Watch tutorials", action: discover)
        lessonAction(.edit, title: "Film and review", action: openTools)
    }

    private func lessonAction(_ symbol: KStepGlyph, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Glyph(symbol: symbol, size: 18, tint: KStepStyle.accent)
                LocalizedText(title).font(.stage(.subheadline, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(12).frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(KStepStyle.paper)
                .background { StageSurface(tone: .mist) }
                .contentShape(Rectangle())
        }.buttonStyle(PressStyle())
    }
    private func resolve() {
        guard let text = link.nilIfBlank, searchRequest == nil else { return }
        focused = false
        guard api.session != nil else { showLinkFailure("Your connection is not ready yet. Please try again."); return }
        // Preserve exactly what was entered. Search owns loading, errors and cursor
        // pagination; do not fall back to the old landing-page resolver.
        searchRequest = LessonSearch(query: text)
    }
    private func showLinkFailure(_ message: String) {
        linkFailure = message
        showingLinkFailure = true
    }
}

// Disabled artwork already has its own legible palette; do not fade the entire
// button into the paper surface as the shared legacy PressStyle does.
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
            SheetHeading(title: "Open your next lesson") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    StageArtwork(kind: .lesson, height: 150)
                    FeatureRow(symbol: .link, title: "1. Copy a KStep link", detail: "Use a lesson link or code shared through KStep.")
                    FeatureRow(symbol: .search, title: "2. Paste it above", detail: "Tap Paste or enter the lesson code exactly as received. Codes are case-sensitive.")
                    FeatureRow(symbol: .play, title: "3. Open and watch", detail: "Tap Open lesson to find matching lessons, then swipe to watch.")
                    LocalizedText("No results? Check your input, or ask the sender for a new link.")
                        .font(.stage(.footnote)).foregroundStyle(KStepStyle.secondary)
                    ActionButton(title: "Got it") { dismiss() }
                }.kstepPage()
            }
        }.kstepScreenBackground().foregroundStyle(.white)
    }
}
