import SwiftUI
import AVFoundation

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var offline: OfflineStore
    @EnvironmentObject private var commerce: CommerceStore
    @State private var showingExportMembership = false
    var edit: (PracticeRecording) -> Void
    @Binding var filter: String
    @State private var player: PlayerRoute?
    @State private var sharing: SharedFile?
    @State private var removing: PracticeRecording?
    @State private var removingDownload: OfflineVideo?
    @State private var sharingMovieID: UUID?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    private var category: Category { Category(rawValue: filter) ?? .saved }
    private var localMovies: [PracticeRecording] {
        library.movies.filter { $0.isExport == (category == .exports) }
    }

    private enum Category: String, CaseIterable, Identifiable {
        case saved = "Saved"
        case offline = "Downloads"
        case imports = "Imports"
        case exports = "Exports"

        var id: String { rawValue }
        var title: String {
            switch self {
            case .saved: "Favorites"
            case .offline: "Offline videos"
            case .imports, .exports: rawValue
            }
        }
        var glyph: KStepGlyph {
            switch self {
            case .saved: .bookmark
            case .offline: .download
            case .imports: .folder
            case .exports: .edit
            }
        }
    }

    var body: some View {
        StageScrollView { topInset in
            VStack(spacing: 0) {
                StagePhotoHeader(artwork: "LibraryStudio", height: 218, topInset: topInset) {
                    LocalizedText("Library").font(.stage(.largeTitle, display: true))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .stageColumn().padding(.top, 94).padding(.bottom, 12)
                }
                VStack(alignment: .leading, spacing: 24) {
                    categoryPicker
                    librarySection
                }.kstepPage(top: 0)
            }
        }.kstepScreenBackground().sheet(item: $sharing) { ShareSheet(items: [$0.url]) }
            .sheet(isPresented: $showingExportMembership) { MembershipView(exportRequired: true) }
            .fullScreenCover(item: $player) { PlayerScreen(route: $0) }
            .sheet(item: $removingDownload) { video in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SheetHeading(title: "Remove offline video?") { removingDownload = nil }
                        Text(verbatim: video.clip.title).font(.stage(.headline)).lineLimit(3)
                        LocalizedText("This removes only the offline copy. Your favorite stays saved.")
                            .foregroundStyle(KStepStyle.secondary)
                        ActionButton(title: "Remove download", primary: false) {
                            offline.remove(video); removingDownload = nil
                        }
                        ActionButton(title: "Keep it") { removingDownload = nil }
                    }.padding(24)
                }.kstepScreenBackground().presentationDetents([.medium, .large])
            }
            .sheet(item: $removing) { movie in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        SheetHeading(title: "Delete this local copy?") { removing = nil }
                        Text(verbatim: movie.title).font(.stage(.headline))
                        LocalizedText("This removes the library copy. Your original stays in Photos or Files.").foregroundStyle(KStepStyle.secondary)
                        ActionButton(title: "Delete local copy") { library.delete(movie); removing = nil }
                        ActionButton(title: "Keep it", primary: false) { removing = nil }
                    }.padding(24)
                }.kstepScreenBackground().presentationDetents([.medium, .large])
            }
    }

    @ViewBuilder private var categoryPicker: some View {
        if typeSize.isAccessibilitySize {
            categoryButtons(stacked: true)
        } else {
            ViewThatFits(in: .horizontal) {
                categoryButtons(stacked: false)
                categoryButtons(stacked: true)
            }
        }
    }

    private func categoryButtons(stacked: Bool) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 2))
        return layout {
            ForEach(Category.allCases) { entry in
                categoryButton(entry, stacked: stacked)
            }
        }.padding(5).stageGlass(RoundedRectangle(cornerRadius: 16))
    }

    private func categoryButton(_ entry: Category, stacked: Bool) -> some View {
        let selected = category == entry
        let ink = selected ? KStepStyle.paper : KStepStyle.secondary
        let label = entry == .offline && !stacked ? "Offline" : entry.title
        let layout = stacked ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 5))
        return Button { filter = entry.rawValue } label: {
            layout {
                Glyph(symbol: entry.glyph, size: 17, tint: selected ? KStepStyle.accent : ink)
                LocalizedText(label).font(.stage(.caption, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if stacked { Spacer(minLength: 6) }
                Text(count(in: entry), format: .number.locale(locale)).font(.stage(.caption2))
                    .monospacedDigit().foregroundStyle(KStepStyle.secondary)
            }
                .padding(.horizontal, 5).padding(.vertical, 8)
                .frame(minWidth: stacked ? nil : 65, maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(ink)
                .background(selected ? KStepStyle.paper.opacity(0.15) : .clear,
                            in: RoundedRectangle(cornerRadius: 11))
                .contentShape(Rectangle())
        }.buttonStyle(PressStyle()).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityLabel(LocalizedStringKey(entry.title))
            .accessibilityValue(Text(count(in: entry), format: .number.locale(locale)))
    }

    private var librarySection: some View {
        let total = count(in: category)
        return VStack(alignment: .leading, spacing: 16) {
            SectionLabel(title: category.title, detail: "\(total) \(total == 1 ? "item" : "items") · On this device")
                .accessibilityAddTraits(.isHeader)
            if category == .offline { DownloadAllowanceSummary() }
            downloadStatus
            switch category {
            case .saved:
                if library.favorites.isEmpty {
                    LibraryEmptyState(title: "Build your choreo collection.", message: "Save tutorials as you watch. Come back to the parts you want to drill.")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(library.favorites) { clip in favoriteRow(clip) }
                    }
                }
            case .offline:
                if offline.videos.isEmpty {
                    LibraryEmptyState(title: "Available offline",
                                      message: "Download a lesson from its playback options to watch without a connection.")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(offline.videos) { video in downloadRow(video) }
                    }
                }
            case .imports, .exports:
                if localMovies.isEmpty {
                    LibraryEmptyState(title: category == .exports ? "Ready for your next upload." : "Your practice, in focus.",
                                      message: category == .exports ? "Finish a video or extract its audio in Practice. Your exports will be collected here." : "Choose your dance footage in Practice to keep a local working copy.")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(localMovies) { movie in movieRow(movie) }
                    }
                }
            }
        }
    }

    private func count(in entry: Category) -> Int {
        switch entry {
        case .saved: library.favorites.count
        case .offline: offline.videos.count
        case .imports: library.movies.lazy.filter { !$0.isExport }.count
        case .exports: library.movies.lazy.filter(\.isExport).count
        }
    }

    @ViewBuilder private var downloadStatus: some View {
        if offline.downloadingID != nil || offline.error != nil {
            VStack(alignment: .leading, spacing: 8) {
                if offline.downloadingID != nil {
                    if let title = offline.currentTitle {
                        Text(verbatim: title).font(.stage(.subheadline, weight: .semibold)).lineLimit(2)
                    }
                    LocalizedText("Downloading · \(Int(offline.progress * 100))%")
                        .font(.stage(.caption)).monospacedDigit()
                    Button("Cancel download") { Task { await offline.cancel() } }
                        .buttonStyle(LibraryActionStyle())
                }
                if let error = offline.error {
                    ErrorNote(message: error)
                    if offline.downloadingID != nil {
                        Button("Retry") { Task { await offline.retryCompletion() } }
                            .buttonStyle(LibraryActionStyle())
                    }
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(KStepStyle.surface, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func favoriteRow(_ clip: LessonClip) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button { player = PlayerRoute(clips: library.favorites, startID: clip.id) } label: {
                HStack(spacing: 12) {
                    playableCover(clip.coverURL, width: 62, height: 80)
                    lessonTitle(clip)
                }.contentShape(Rectangle())
            }.buttonStyle(PressStyle())
            removeButton(.bookmark, title: "Remove saved video") { library.toggle(clip) }
        }
        .modifier(LibraryRowSurface())
    }

    private func playableCover(_ url: URL?, width: CGFloat, height: CGFloat) -> some View {
        MediaCover(url: url)
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(alignment: .bottomLeading) {
                Glyph(symbol: .play, size: 15, tint: KStepStyle.paper)
                    .frame(width: 28, height: 28)
                    .background(KStepStyle.ink.opacity(0.88), in: RoundedRectangle(cornerRadius: 7))
                    .padding(3).allowsHitTesting(false)
            }.accessibilityHidden(true)
    }

    private func lessonTitle(_ clip: LessonClip) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: clip.title).font(.stage(.headline)).lineLimit(3)
            if !clip.channel.isEmpty {
                Text(verbatim: clip.channel).font(.stage(.caption))
                    .foregroundStyle(KStepStyle.secondary).lineLimit(2)
            }
        }.fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func downloadRow(_ video: OfflineVideo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { playDownload(video) } label: {
                HStack(spacing: 12) {
                    itemGlyph(.play)
                    Text(verbatim: video.clip.title).font(.stage(.headline)).lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(PressStyle())
            HStack(spacing: 8) {
                VideoExportEntry(clip: offline.playable(video.clip), compact: true)
                Spacer(minLength: 0)
                removeButton(.close, title: "Remove download") { removingDownload = video }
            }
        }
        .modifier(LibraryRowSurface())
    }

    private func movieRow(_ movie: PracticeRecording) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                itemGlyph(movie.filename.hasSuffix("m4a") ? .sound : movie.isExport ? .download : .feed)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: movie.title).font(.stage(.headline)).lineLimit(2)
                    LocalizedDateText(date: movie.date).font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                removeButton(.close, title: "Delete local file") { removing = movie }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { movieActions(movie) }
                VStack(alignment: .leading, spacing: 6) { movieActions(movie) }
            }
        }
        .modifier(LibraryRowSurface())
    }

    @ViewBuilder private func movieActions(_ movie: PracticeRecording) -> some View {
        if movie.filename.hasSuffix("m4a") == false {
            Button("Edit") { edit(movie) }.buttonStyle(LibraryActionStyle())
        }
        Button(LocalizedStringKey(sharingMovieID == movie.id ? "Preparing export…" : "Export")) {
            shareMovie(movie)
        }.buttonStyle(LibraryActionStyle()).disabled(sharingMovieID != nil)
    }

    private func itemGlyph(_ symbol: KStepGlyph) -> some View {
        Glyph(symbol: symbol, size: 19, tint: KStepStyle.accent)
            .frame(width: 46, height: 46)
            .background(KStepStyle.raised, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityHidden(true)
    }

    private func removeButton(_ symbol: KStepGlyph, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Glyph(symbol: symbol, size: 16, tint: KStepStyle.accent)
                .frame(width: 36, height: 36)
                .background(KStepStyle.raised, in: RoundedRectangle(cornerRadius: 9))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(PressStyle()).accessibilityLabel(LocalizedStringKey(title))
    }

    private func playDownload(_ video: OfflineVideo) {
        let clips = offline.videos.compactMap { item -> LessonClip? in
            offline.cached(item.id) == nil ? nil : offline.playable(item.clip)
        }
        if clips.contains(where: { $0.id == video.id }) {
            player = PlayerRoute(clips: clips, startID: video.id)
        } else { offline.error = "This download is no longer on this device. Download it again." }
    }

    private func shareMovie(_ movie: PracticeRecording) {
        guard commerce.canExportMedia else {
            showingExportMembership = true
            return
        }
        sharingMovieID = movie.id
        Task {
            defer { sharingMovieID = nil }
            do { sharing = SharedFile(url: try await library.shareFile(for: movie, commerce: commerce)) }
            catch { library.error = error.localizedDescription }
        }
    }
}

private struct LibraryRowSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10).background(KStepStyle.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct LibraryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.stage(.footnote, weight: .bold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 13).padding(.vertical, 8)
            .frame(minWidth: 44, minHeight: 44)
            .foregroundStyle(KStepStyle.ink)
            .background(KStepStyle.mist, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
            .opacity(!enabled ? 0.58 : configuration.isPressed ? 0.72 : 1)
    }
}

// Uses the existing original bitmap action surfaces; no new system artwork.
struct OfflineDownloadButton: View {
    let clip: LessonClip
    var starting = false
    @EnvironmentObject private var offline: OfflineStore
    @EnvironmentObject private var quota: QuotaStore
    @EnvironmentObject private var commerce: CommerceStore
    @State private var downloadGate = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DownloadAllowanceSummary()
            if offline.cached(clip.id) != nil || clip.playbackURL.isFileURL {
                LocalizedText("Available offline").font(.stage(.subheadline)).foregroundStyle(KStepStyle.accent)
                DownloadCompletionNotice()
            } else if starting || offline.preparingID == clip.id {
                ActionButton(title: "Preparing download…", primary: false, busy: true) { }
                LocalizedText("Preparing download…").font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
            } else if offline.downloadingID == clip.id {
                LocalizedText("Downloading · \(Int(offline.progress * 100))%").font(.stage(.caption))
                ActionButton(title: "Cancel download", primary: false) { Task { await offline.cancel() } }
            } else {
                ActionButton(title: "Download for offline", primary: false) {
                    if quota.mayDownload(clip.id, premium: commerce.premium) {
                        Task { await offline.download(clip) }
                    } else { downloadGate = true }
                }.disabled(offline.busy || clip.playbackURL.isFileURL)
                    .accessibilityIdentifier("player.downloadOffline")
                if offline.isRestoring {
                    LocalizedText("Restoring downloads…").font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
                } else if offline.busy {
                    LocalizedText("Another download is in progress.").font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
                }
            }
            VideoExportEntry(clip: clip)
            if let error = offline.error {
                ErrorNote(message: error)
                if offline.downloadingID == clip.id {
                    ActionButton(title: "Retry", primary: false) { Task { await offline.retryCompletion() } }
                }
            }
        }.sheet(isPresented: $downloadGate) { MembershipView(rewardKind: .download) }
    }
}

// A separate, always-visible workflow; users need not visit the cache panel.
struct VideoExportEntry: View {
    let clip: LessonClip
    var compact = false
    @State private var showingExport = false
    @EnvironmentObject private var commerce: CommerceStore
    var body: some View {
        Group {
            if compact {
                Button("Export") { showingExport = true }.buttonStyle(LibraryActionStyle())
            } else {
                ActionButton(title: "Export video", primary: false) { showingExport = true }
            }
        }.accessibilityIdentifier("player.openExport")
            .sheet(isPresented: $showingExport) {
                if commerce.canExportMedia { OfflineExportSheet(clip: clip) }
                else { MembershipView(exportRequired: true) }
            }
    }
}

private struct OfflineExportSheet: View {
    let clip: LessonClip
    @Environment(\.dismiss) private var dismiss
    @StateObject private var departure = ExportDeparture()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeading(title: "Export video") { departure.request { dismiss() } }
                Text(verbatim: clip.title).font(.stage(.subheadline)).lineLimit(2)
                OfflineExportButton(clip: clip)
            }.padding(22)
        }.kstepScreenBackground().presentationDetents([.medium, .large])
            .environmentObject(departure)
            .modifier(ExportDepartureProtection(departure: departure))
    }
}

// One owner for the close button, explicit cancel and interactive dismissal.
@MainActor
final class ExportDeparture: ObservableObject {
    @Published private(set) var running = false
    @Published var confirming = false
    private var cancellation: (() -> Void)?
    private var afterCancellation: (() -> Void)?
    func begin(cancel: @escaping () -> Void) { running = true; cancellation = cancel }
    func finish() {
        running = false; cancellation = nil
        confirming = false; afterCancellation = nil
    }
    func request(_ close: @escaping () -> Void = {}) {
        guard running else { close(); return }
        afterCancellation = close; confirming = true
    }
    func keepWorking() { confirming = false; afterCancellation = nil }
    func stop() {
        let close = afterCancellation
        cancellation?()
        confirming = false; afterCancellation = nil
        close?()
    }
}

struct ExportDepartureProtection: ViewModifier {
    @ObservedObject var departure: ExportDeparture
    func body(content: Content) -> some View {
        content.interactiveDismissDisabled(departure.running)
            .accessibilityHidden(departure.confirming)
            .overlay {
                if departure.confirming {
                    GeometryReader { container in
                        ScrollView {
                            VStack(spacing: 18) {
                                LocalizedText("Stop this export?").font(.stage(.headline))
                                LocalizedText("The export is still in progress. Leaving now cancels it. Your video stays safe.")
                                    .font(.stage(.subheadline)).foregroundStyle(KStepStyle.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                ActionButton(title: "Keep exporting", action: departure.keepWorking)
                                ActionButton(title: "Stop export", primary: false, action: departure.stop)
                            }.padding(22).frame(maxWidth: 360)
                                .background { StageSurface(tone: .plum) }.padding(20)
                                .frame(maxWidth: .infinity, minHeight: container.size.height)
                        }.background(.black.opacity(0.7))
                            .accessibilityAddTraits(.isModal)
                    }
                }
            }
    }
}

struct DownloadCompletionNotice: View {
    @EnvironmentObject private var offline: OfflineStore
    @EnvironmentObject private var library: LibraryStore
    var body: some View {
        Group {
            if offline.completedDownloadID != nil {
                HStack(spacing: 12) {
                    LocalizedText("Downloaded. Watch offline in Library.")
                        .font(.stage(.caption)).fixedSize(horizontal: false, vertical: true)
                    Button("View") {
                        offline.completedDownloadID = nil
                        library.openDownloads()
                    }.buttonStyle(CompactActionStyle())
                    IconButton(symbol: .close, label: "Dismiss message") { offline.completedDownloadID = nil }
                }.padding(12).foregroundStyle(KStepStyle.paper)
                    .background { StageSurface(tone: .plum) }
                    .padding(.horizontal, 12)
            }
        }.task(id: offline.completedDownloadID) {
            guard let notice = offline.completedDownloadID else { return }
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            if offline.completedDownloadID == notice { offline.completedDownloadID = nil }
        }
    }
}

// Uncached exports use the same download admission and completion journal.
// Export is a Plus benefit; cached copies still pass the membership check.
private struct OfflineExportButton: View {
    let clip: LessonClip
    @EnvironmentObject private var departure: ExportDeparture
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var offline: OfflineStore
    @EnvironmentObject private var quota: QuotaStore
    @EnvironmentObject private var commerce: CommerceStore
    @State private var downloadGate = false
    @State private var preparingSource = false
    @State private var exportTask: Task<Void, Never>?
    @State private var sharing: SharedFile?
    @State private var exportError: String?
    @State private var exportedFile: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ActionButton(title: preparingSource ? "Preparing export…" : exportTask == nil ? "Export video" : "Exporting…",
                         primary: false, busy: exportTask != nil, action: startExport)
                .accessibilityIdentifier("player.exportVideo")
            if !clip.playbackURL.isFileURL, offline.cached(clip.id) == nil {
                LocalizedText("We download the video before exporting. Existing downloads are reused.")
                    .font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
                DownloadAllowanceSummary()
            }
            if preparingSource, offline.downloadingID == clip.id {
                LocalizedText("Downloading · \(Int(offline.progress * 100))%").font(.stage(.caption))
            }
            if exportTask != nil {
                Button("Cancel export") { departure.request() }.buttonStyle(CompactActionStyle())
            }
            if let exportError { ErrorNote(message: exportError) }
        }
        .sheet(item: $sharing) { ShareSheet(items: [$0.url]) }
        .sheet(isPresented: $downloadGate) { MembershipView(exportRequired: true) }
        .onDisappear { exportTask?.cancel() }
    }

    private func startExport() {
        guard exportTask == nil else { return }
        guard commerce.canExportMedia else { downloadGate = true; return }
        if !clip.playbackURL.isFileURL, offline.cached(clip.id) == nil,
           !quota.mayDownload(clip.id, premium: commerce.premium) {
            downloadGate = true
            return
        }
        if let exportedFile, FileManager.default.fileExists(atPath: exportedFile.path) {
            sharing = SharedFile(url: exportedFile); return
        }
        exportError = nil
        exportTask = Task { @MainActor in
            defer { exportTask = nil; preparingSource = false; departure.finish() }
            var ownsDownload = false
            var converted: URL?
            defer { if let converted { try? FileManager.default.removeItem(at: converted) } }
            do {
                try commerce.requireMediaExport()
                var source = clip.playbackURL
                if !source.isFileURL || offline.cached(clip.id)?.isHLS == true {
                    preparingSource = true
                    // A cache request may already be finishing for this clip.
                    // Let it finish, then decide whether its result is a file
                    // or whether the original-file download is still needed.
                    if offline.downloadingID == clip.id {
                        for await downloadID in offline.$downloadingID.values {
                            try Task.checkCancellation()
                            if downloadID != clip.id { break }
                        }
                    }
                    try Task.checkCancellation()
                    if offline.cached(clip.id)?.isHLS != false, offline.downloadingID != clip.id {
                        guard !offline.busy else { throw KStepError.service("Another download is in progress.") }
                        ownsDownload = true
                        await offline.download(clip, forExport: true)
                    }
                    // Subscribe to the shared download state, including its
                    // current value, so a very fast completion is not missed.
                    for await downloadID in offline.$downloadingID.values {
                        try Task.checkCancellation()
                        if let cached = offline.cached(clip.id), !cached.isHLS { source = cached.url; break }
                        guard downloadID == clip.id else {
                            throw KStepError.service(offline.error ?? "Download failed. No download allowance was used.")
                        }
                    }
                    try Task.checkCancellation()
                    guard source.isFileURL else { throw KStepError.storage }
                    preparingSource = false
                }
                var output = source
                if !["mp4", "mov", "m4v"].contains(source.pathExtension.lowercased()) {
                    let asset = AVURLAsset(url: source)
                    guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality),
                          session.supportedFileTypes.contains(.mp4) else {
                        throw KStepError.service("This video format cannot be exported. Please use an MP4 or MOV file.")
                    }
                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
                    converted = destination
                    session.outputURL = destination
                    session.outputFileType = .mp4
                    await withTaskCancellationHandler {
                        await withCheckedContinuation { continuation in
                            session.exportAsynchronously { continuation.resume() }
                        }
                    } onCancel: { session.cancelExport() }
                    try Task.checkCancellation()
                    guard session.status == .completed else {
                        throw KStepError.service("Video export failed. Please try again.")
                    }
                    output = destination
                }
                try Task.checkCancellation()
                try commerce.requireMediaExport()
                let recording = try await library.importMovie(output, exported: true, title: clip.title)
                let url = try await library.shareFile(for: recording, commerce: commerce)
                exportedFile = url
                if !Task.isCancelled { sharing = SharedFile(url: url) }
            } catch is CancellationError {
                if ownsDownload, offline.downloadingID == clip.id { await offline.cancel() }
            }
            catch {
                exportError = error.localizedDescription
            }
        }
        departure.begin { exportTask?.cancel() }
    }
}

// Shared, live allowance display at the download decision and in the offline library.
struct DownloadAllowanceSummary: View {
    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var quota: QuotaStore
    @EnvironmentObject private var commerce: CommerceStore
    @State private var showingReward = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LocalizedText("Downloads left").font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
            LocalizedText(api.session == nil ? "Connect to refresh your allowance." :
                            commerce.premium || quota.downloadsUnlimited ? "Unlimited" :
                            quota.usage == nil ? "Loading…" : "\(quota.downloadsLeft) downloads left today")
                .font(.stage(.subheadline, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            if quota.usage != nil, !commerce.premium { AllowanceResetText() }
            if quota.canRequestReward(for: .download, premium: commerce.premium) {
                ActionButton(title: "Get more downloads", primary: false) { showingReward = true }
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background { StageSurface(tone: .plum) }
            .accessibilityElement(children: .contain)
            .onAppear { quota.resetIfNeeded() }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in quota.resetIfNeeded() }
            .sheet(isPresented: $showingReward) { MembershipView(rewardKind: .download) }
    }
}

private struct LibraryEmptyState: View {
    let title: String
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LocalizedText(title).font(.stage(.title3, weight: .semibold))
            LocalizedText(message).font(.stage(.subheadline)).foregroundStyle(KStepStyle.secondary)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Divider().overlay(KStepStyle.line).allowsHitTesting(false) }
    }
}
