import SwiftUI

struct DancePracticeEntry: View {
    let openJournal: () -> Void
    var body: some View {
        Button(action: openJournal) {
            VStack(alignment: .leading, spacing: 10) {
                LocalizedText("Rehearsal log").font(.stage(.title3, display: true))
                LocalizedText("Count it, run it, mark it clean.").font(.stage(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
                EightCountRail(highlighted: [1], compact: true).frame(maxWidth: 260, alignment: .leading)
            }
            .foregroundStyle(KStepStyle.paper)
            .padding(20).frame(maxWidth: .infinity, minHeight: 172, alignment: .bottomLeading)
            .background {
                ZStack {
                    KStepStyle.surface
                    if ArtworkCatalog.has("PracticeHero") { Image("PracticeHero").resizable().scaledToFill() }
                    LinearGradient(colors: [.clear, KStepStyle.background.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)).contentShape(Rectangle())
        }.buttonStyle(PressStyle()).accessibilityIdentifier("practice.openJournal")
    }
}

struct DancePracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @StateObject private var journal = DancePracticeJournal()
    @State private var section = SongSection.chorus
    @State private var eightCount = 1
    @State private var tempo = PracticeTempo.threeQuarters
    @State private var mirrored = true
    @State private var routine = ""
    @State private var runNote = ""
    @State private var showingHistory = false
    @State private var selectedSession: DancePracticeSession?
    @State private var pendingRemoval: DancePracticeSession?
    @State private var sharedExport: SharedFile?
    @FocusState private var routineFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SheetHeading(title: "Rehearsal log") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    KStepIllustration(name: "PracticeHero", height: 150)
                    ChoiceStrip(values: ["Practice", "Sessions"], selected: showingHistory ? "Sessions" : "Practice") {
                        showingHistory = $0 == "Sessions"
                    }
                    if let message = journal.storageMessage { ErrorNote(message: message) }
                    if showingHistory { history } else { practice }
                }.kstepPage().frame(maxWidth: 660).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(KStepStyle.paper).kstepScreenBackground()
            .sheet(item: $selectedSession) { session in
                VStack(spacing: 0) {
                    SheetHeading(title: "Session results") { selectedSession = nil }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            routineTitle(session).font(.stage(.title3, weight: .semibold))
                            Text(session.startedAt, format: .dateTime.year().month().day().hour().minute().locale(locale))
                                .font(.stage(.subheadline)).foregroundStyle(KStepStyle.secondary)
                            summary(session)
                            sectionBreakdown(session)
                            ForEach(session.runs) { run in
                                if let note = run.note {
                                    VStack(alignment: .leading, spacing: 6) {
                                        LocalizedText(run.section.label).font(.stage(.headline))
                                        Text(verbatim: note).font(.stage(.subheadline))
                                    }
                                }
                            }
                            ActionButton(title: "Export session CSV", primary: false) {
                                if let url = journal.exportSession(session) { sharedExport = SharedFile(url: url) }
                            }
                            if let message = journal.storageMessage { ErrorNote(message: message) }
                            Button { pendingRemoval = session } label: { LocalizedText("Delete session") }
                                .buttonStyle(CompactActionStyle())
                        }.kstepPage()
                    }
                }.kstepScreenBackground().foregroundStyle(KStepStyle.paper)
                    .sheet(item: $sharedExport) { ShareSheet(items: [$0.url]) }
                    .fullScreenCover(item: $pendingRemoval) { session in
                        AccountDecisionDialog(title: "Delete session?", message: "This removes this rehearsal session and its run records.",
                            confirmTitle: "Delete session", destructive: true,
                            cancel: { pendingRemoval = nil }) {
                                journal.removeSession(session.id)
                                pendingRemoval = nil
                                if !journal.completedSessions.contains(where: { $0.id == session.id }) { selectedSession = nil }
                            }.presentationBackground(.clear)
                    }
            }
    }

    @ViewBuilder private var practice: some View {
        if let session = journal.activeSession {
            routineTitle(session).font(.stage(.headline))
            LocalizedText("Set what you are drilling, run it, then mark how it went.")
                .font(.stage(.subheadline)).foregroundStyle(KStepStyle.secondary)
            LocalizedText("Section").font(.stage(.subheadline, weight: .semibold))
            ChoiceStrip(values: SongSection.allCases.map(\.label), selected: section.label) { label in
                if let value = SongSection.allCases.first(where: { $0.label == label }) { section = value }
            }
            LocalizedText("Eight-count").font(.stage(.subheadline, weight: .semibold))
            EightCountRail(selected: eightCount) { eightCount = $0 }
            LocalizedText("Practice speed").font(.stage(.subheadline, weight: .semibold))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { tempoChoices; Spacer(minLength: 8); mirrorToggle }
                VStack(alignment: .leading, spacing: 10) { tempoChoices; mirrorToggle }
            }
            summary(session)
            TextField("Run note (optional)", text: $runNote, axis: .vertical)
                .lineLimit(2...5).kstepField()
            LocalizedText("How did that run go?").font(.stage(.headline))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(RunResult.allCases) { result in
                    ActionButton(title: result.label, primary: result == .clean) {
                        if journal.record(result, section: section, eightCount: eightCount, tempo: tempo,
                                          mirrored: mirrored, note: runNote) {
                            runNote = ""
                        }
                    }.disabled(!journal.available)
                }
            }
            HStack {
                Button { journal.undoLastRun() } label: { LocalizedText("Undo last run") }
                    .buttonStyle(CompactActionStyle()).disabled(session.runs.isEmpty)
                Spacer(minLength: 0)
            }
            ActionButton(title: "Finish session", primary: false) {
                journal.finishSession()
                if journal.activeSession == nil {
                    runNote = ""
                    showingHistory = true
                }
            }
        } else {
            LocalizedText("Clean it up, one eight-count at a time.").font(.stage(.title2, display: true))
                .fixedSize(horizontal: false, vertical: true)
            LocalizedText("Log every run-through by section and count. See which parts are clean and which need another pass.")
                .font(.stage(.subheadline)).foregroundStyle(KStepStyle.secondary)
            TextField(text: $routine, prompt: Text(verbatim: L10n.display("Song or routine name (optional)", language: AppLanguage.from(locale)))
                .foregroundStyle(KStepStyle.secondary)) {
                LocalizedText("Song or routine name")
            }
            .focused($routineFocused).submitLabel(.done).kstepField()
            ActionButton(title: "Start a rehearsal") {
                routineFocused = false
                journal.beginSession(routine: routine)
                routine = ""
            }.disabled(!journal.available)
        }
        LocalizedText("Record between run-throughs. Results are your own entries, not automatic video analysis.")
            .font(.stage(.footnote)).foregroundStyle(KStepStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tempoChoices: some View {
        ChoiceStrip(values: PracticeTempo.allCases.map(\.label), selected: tempo.label) { label in
            if let value = PracticeTempo.allCases.first(where: { $0.label == label }) { tempo = value }
        }
    }

    private var mirrorToggle: some View {
        Button { mirrored.toggle() } label: {
            LocalizedText(mirrored ? "Mirrored: On" : "Mirrored: Off")
        }.buttonStyle(CompactActionStyle())
            .accessibilityAddTraits(mirrored ? .isSelected : [])
    }

    @ViewBuilder private var history: some View {
        if journal.completedSessions.isEmpty {
            LocalizedText("Your first rehearsal starts here.").font(.stage(.headline))
            LocalizedText("Finished sessions appear here with their clean runs by section.")
                .font(.stage(.subheadline)).foregroundStyle(KStepStyle.secondary)
        } else {
            ForEach(journal.completedSessions) { session in
                Button { selectedSession = session } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        routineTitle(session).font(.stage(.headline)).lineLimit(2)
                        Text(session.startedAt, format: .dateTime.month().day().hour().minute().locale(locale))
                            .font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
                        summary(session)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background { StageSurface(tone: .plum) }.contentShape(Rectangle())
                }.buttonStyle(PressStyle())
            }
        }
    }

    @ViewBuilder private func routineTitle(_ session: DancePracticeSession) -> some View {
        if let name = session.routine.nilIfBlank { Text(verbatim: name) }
        else { LocalizedText("Untitled routine") }
    }

    private func summary(_ session: DancePracticeSession) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 22) { metrics(session) }
            VStack(alignment: .leading, spacing: 10) { metrics(session) }
        }.accessibilityElement(children: .combine)
    }

    @ViewBuilder private func metrics(_ session: DancePracticeSession) -> some View {
        metric("Runs", value: session.runs.count.formatted(.number.locale(locale)))
        metric("Clean runs", value: session.cleanCount.formatted(.number.locale(locale)))
        metric("Clean at 1×", value: session.fullSpeedCleanCount.formatted(.number.locale(locale)))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: value).font(.stage(.title2, weight: .semibold)).monospacedDigit()
            LocalizedText(title).font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func sectionBreakdown(_ session: DancePracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            LocalizedText("By section").font(.stage(.headline))
            ForEach(SongSection.allCases.filter { section in session.runs.contains { $0.section == section } }) { section in
                let runs = session.runs.filter { $0.section == section }
                let clean = runs.filter { $0.result.isClean }.count
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        LocalizedText(section.label)
                        Spacer(minLength: 8)
                        Text(verbatim: "\(clean) / \(runs.count)").monospacedDigit()
                    }.font(.stage(.subheadline))
                    EightCountRail(highlighted: Set(runs.filter { $0.result.isClean }.map(\.eightCount)), compact: true)
                        .accessibilityHidden(true)
                }
            }
            LocalizedText("Clean runs / runs logged. Highlighted counts had at least one clean run.")
                .font(.stage(.footnote)).foregroundStyle(KStepStyle.secondary)
        }
    }
}
