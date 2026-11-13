import SwiftUI
import OSLog

@main
struct KStepApp: App {
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = AppLanguage.systemSelection
    @Environment(\.scenePhase) private var appPhase
    @State private var systemLanguage = AppLanguage.systemLanguage()
    private var language: AppLanguage { AppLanguage(rawValue: languageCode) ?? systemLanguage }
    @StateObject private var api: APIClient
    @StateObject private var library: LibraryStore
    @StateObject private var quota: QuotaStore
    @StateObject private var commerce: CommerceStore
    @StateObject private var offline: OfflineStore
    @StateObject private var ads: RewardedAds
    @StateObject private var accountAccess = AccountAccessFlow()
    init() {
        let api = APIClient()
        let quota = QuotaStore()
        _api = StateObject(wrappedValue: api)
        _library = StateObject(wrappedValue: LibraryStore())
        _quota = StateObject(wrappedValue: quota)
        let commerce = CommerceStore(api: api, quota: quota)
        _commerce = StateObject(wrappedValue: commerce)
        _offline = StateObject(wrappedValue: OfflineStore(api: api, quota: quota, commerce: commerce))
        _ads = StateObject(wrappedValue: RewardedAds())
    }
    var body: some Scene {
        WindowGroup {
            KStepStartupHost().environmentObject(api).environmentObject(library)
                .environmentObject(quota).environmentObject(commerce).environmentObject(ads).environmentObject(offline)
                .environmentObject(accountAccess)
                .environment(\.locale, language.locale)
                .environment(\.layoutDirection, language.direction)
                .font(.stage(.body))
                .preferredColorScheme(.dark).tint(KStepStyle.accent)
                .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
                    systemLanguage = AppLanguage.systemLanguage()
                }
                .onChange(of: appPhase) { _, phase in
                    if phase == .active { systemLanguage = AppLanguage.systemLanguage() }
                }
        }
    }
}

// Keeps the original splash visible during the bounded cold-start ad opportunity.
// Guest authentication prepares configuration and opens the app directly.
struct KStepStartupHost: View {
    @EnvironmentObject private var ads: RewardedAds
    @EnvironmentObject private var commerce: CommerceStore
    @EnvironmentObject private var accountAccess: AccountAccessFlow
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var finished = false
    @State private var startupBegan = ContinuousClock.now

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            // Mount once so local content and authentication prepare while the
            // bounded app-open opportunity runs, without rebuilding navigation.
            KStepRootView()
                .allowsHitTesting(finished)
                .accessibilityHidden(!finished)
            if !finished {
                KStepStartupView(showContinue: commerce.api.configuration.adsTestMode && ads.isPreparingAppOpen) {
                    ads.continueStartup()
                }.transition(.opacity)
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, !finished else { return }
            ads.beginStartup(commerce: commerce, accountAccess: accountAccess)
        }
        .onReceive(ads.$startupFinished) { complete in
            if complete, !finished {
                Logger(subsystem: "app.kstep", category: "Startup")
                    .info("Home became interactive after \(startupBegan.duration(to: .now).description, privacy: .public)")
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { finished = true }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { ads.didEnterBackground() }
            if phase == .active, finished {
                ads.didBecomeActive(commerce: commerce, accountAccess: accountAccess)
            }
        }
    }
}

struct KStepStartupView: View {
    @Environment(\.locale) private var locale
    let showContinue: Bool
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            // Match the launch storyboard's mark during the transition.
            KStepIllustration(name: "LaunchMark", height: 108).frame(width: 108)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .all)
            VStack {
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    ProgressView().tint(KStepStyle.accent)
                        .accessibilityLabel(Text(verbatim: L10n.text("Loading…", language: AppLanguage.from(locale))))
                    if showContinue {
                        Button(action: onContinue) {
                            LocalizedText("Continue to app").font(.stage(.subheadline, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(KStepStyle.paper)
                                .padding(.horizontal, 16).frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }.buttonStyle(PressStyle())
                    }
                }.padding(.horizontal, 20).padding(.bottom, 24)
            }
        }.background(Color("LaunchBackground").ignoresSafeArea())
    }
}

enum KStepTab: Int, CaseIterable, Hashable {
    case home, discover, tools, library, me
    var name: String { ["Rehearsal", "Discover", "Practice", "Library", "Me"][rawValue] }
    // Original single-colour tab artwork; the system tab bar tints it.
    var artwork: String { ["TabHome", "TabDiscover", "TabTools", "TabLibrary", "TabMe"][rawValue] }
}

// System tab item: title and original image, so the bar can follow iPhone Duo's
// vertical bar layout and move titles into the system overflow when needed.
private struct KStepTabItem: View {
    let tab: KStepTab
    @Environment(\.locale) private var locale
    var body: some View {
        Label {
            Text(verbatim: L10n.display(tab.name, language: AppLanguage.from(locale)))
        } icon: {
            Image(tab.artwork).renderingMode(.template)
        }
    }
}

private extension View {
    func kstepTab(_ tab: KStepTab) -> some View {
        tabItem { KStepTabItem(tab: tab) }
            .tag(tab)
            .modifier(StageTabBar())
            .accessibilityIdentifier("tab.\(tab.name.lowercased())")
    }
}

private struct StageTabBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Native glass adapts when Duo places the tab bar along a side.
            content.toolbarColorScheme(.dark, for: .tabBar)
        } else {
            content
                .toolbarBackground(.regularMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
        }
    }
}

struct KStepRootView: View {
    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var commerce: CommerceStore
    @EnvironmentObject private var quota: QuotaStore
    @EnvironmentObject private var offline: OfflineStore
    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage("root.tab") private var tab: KStepTab = .home
    @State private var editing: PracticeRecording?
    @SceneStorage("home.linkDraft") private var linkDraft = ""
    @State private var revealLinkComposer = false
    @State private var libraryFilter = "Saved"
    var body: some View {
        TabView(selection: $tab) {
            HomeView(openAccount: { tab = .me }, discover: { tab = .discover }, openTools: { tab = .tools },
                     link: $linkDraft, revealLinkComposer: $revealLinkComposer)
                .kstepTab(.home)
            ToolsView().kstepTab(.tools)
            // The lesson feed owns player and quota state only while visible.
            Group {
                if tab == .discover {
                    DiscoverView(onExit: { tab = .home }, onOpenLesson: {
                        revealLinkComposer = true
                        tab = .home
                    })
                } else { KStepStyle.background.ignoresSafeArea() }
            }.kstepTab(.discover)
            LibraryView(edit: { editing = $0 }, filter: $libraryFilter).kstepTab(.library)
            AccountView().kstepTab(.me)
        }
        .tint(KStepStyle.accent)
        .foregroundStyle(.white)
            .background { KStepStyle.background.ignoresSafeArea(.container, edges: .all) }
            .sheet(item: $editing) { EditorSheet(initialMovie: $0) }
            .overlay(alignment: .top) {
                if tab != .discover { DownloadCompletionNotice().padding(.top, 8) }
            }
            .task(id: library.downloadsRequest) {
                guard library.downloadsRequest != nil else { return }
                // Full-screen players dismiss first; then move the underlying tab.
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                editing = nil
                libraryFilter = "Downloads"
                tab = .library
            }
            .task(id: api.session?.userId.value) {
                guard api.session != nil else { return }
                if !commerce.rightsVerified || commerce.release == nil { await commerce.refresh() }
                await offline.resumePending()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { quota.resetIfNeeded() }
            }
            .overlay(alignment: .top) {
                if let message = library.error {
                    HStack {
                        LocalizedText(message).font(.stage(.subheadline))
                        IconButton(symbol: .close, label: "Dismiss message") { library.error = nil }
                    }.padding(14).background(KStepStyle.raised, in: RoundedRectangle(cornerRadius: 18)).padding()
                }
            }
            .modifier(AccountBusyModifier())
    }
}

// A network recovery surface, not a second login or consent gate.
struct ConnectionPanel: View {
    @EnvironmentObject private var api: APIClient
    @State private var error: String?
    @State private var connecting = false
    @State private var attempt = 0

    var body: some View {
        VStack(spacing: 24) {
            if let error {
                MessagePanel(title: "Let’s reconnect.", message: error)
                ActionButton(title: "Try again", busy: connecting) { attempt += 1 }
            } else {
                AccountLoadingIndicator(title: "Setting up your practice room…")
            }
            PolicyLinks()
        }
        .frame(maxWidth: 440).frame(maxWidth: .infinity)
        .task(id: attempt) {
            guard api.session == nil else { return }
            connecting = true
            error = nil
            defer { connecting = false }
            do { try await api.prepareVisitor() }
            catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
}
