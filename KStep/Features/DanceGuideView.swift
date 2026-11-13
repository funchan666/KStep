import SwiftUI

// Bundled, original editorial content. Reading never calls video, quota or advertising APIs.
// Evergreen practice advice only: no artist names, songs, rankings or dates.
private struct DanceNote: Identifiable {
    struct Section {
        let title: String
        let body: String
        init(_ title: String, _ body: String) { self.title = title; self.body = body }
    }
    let id: String
    let category: String
    let title: String
    let shortTitle: String
    let summary: String
    let cover: GuideArtwork.Subject
    let sections: [Section]
    let takeaway: String

    static let all: [DanceNote] = [
        DanceNote(
            id: "counts", category: "Basics", title: "Count it in eights.", shortTitle: "Counting",
            summary: "Most choreography is built on eight-beat phrases.", cover: .counts,
            sections: [
                .init("Find the one",
                      "Listen for the strong beat where a phrase begins. Tap it, then count 1 to 8 out loud as the music plays. Most pop songs keep this grouping through a whole section."),
                .init("Use the and",
                      "Fast moves often land between counts. Say \u{201C}1 and 2 and\u{201D} to place them. If a move feels rushed, check whether it belongs on the and."),
                .init("Write the counts down",
                      "Before learning a step, note which count each move lands on. A short note such as \u{201C}5 hit, 6 turn\u{201D} is easier to recall than a description.")
            ],
            takeaway: "If you lose your place, wait for the next 1 and come back in."),
        DanceNote(
            id: "mirror", category: "Practice", title: "Learn it mirrored.", shortTitle: "Mirroring",
            summary: "Make left and right match the screen.", cover: .mirror,
            sections: [
                .init("Facing or back view",
                      "Some tutorials face you, others show the dancer\u{2019}s back. When the dancer faces you, their right arm appears on your left."),
                .init("Flip the picture",
                      "A mirrored video lets you copy the screen directly, like a studio mirror. Use Mirror in the Practice editor on your own clips."),
                .init("Check the real direction",
                      "Before you perform or film, run it once unmirrored so your travel direction and formation match the original.")
            ],
            takeaway: "Mirror to learn. Unmirror to check."),
        DanceNote(
            id: "chunk", category: "Practice", title: "Chunk the choreography.", shortTitle: "Chunking",
            summary: "Small sections, slow speed, then link them.", cover: .chunk,
            sections: [
                .init("One eight-count at a time",
                      "Learn a single eight-count until you can do it without watching, then add the next one."),
                .init("Slow it down",
                      "Start at 0.5× or 0.75× to see weight changes and arm paths. Move to full speed only when the slower run is clean."),
                .init("Practise the joins",
                      "Run the last count of one section into the first count of the next. Many mistakes happen in a transition, not inside the step.")
            ],
            takeaway: "Log which eight-counts are clean, and start your next session with the rest."),
        DanceNote(
            id: "point", category: "Performance", title: "Nail the point move.", shortTitle: "Point move",
            summary: "The signature move people recognise.", cover: .point,
            sections: [
                .init("Start with the hook",
                      "Many group dances have one recognisable move in the chorus. Learning it first gives you something to show early and keeps practice motivating."),
                .init("Hit and hold",
                      "Sharpness comes from clean stops. Arrive on the count, hold for a moment, then move on."),
                .init("Match the group",
                      "In group choreography, arm height, angles and timing should line up. Film a run and compare it with the tutorial side by side.")
            ],
            takeaway: "Accurate timing reads as sharper than bigger movement."),
        DanceNote(
            id: "stage", category: "Performance", title: "Perform, don\u{2019}t just repeat.", shortTitle: "Expression",
            summary: "Face, eye line and energy are part of the dance.", cover: .stage,
            sections: [
                .init("Practise your expression",
                      "Expression belongs to the choreography. Try one full run focusing only on your face and eye line."),
                .init("Know where the camera is",
                      "When filming, decide where the lens is and treat it as your audience. Look into it on the moments meant for the camera."),
                .init("Review the take",
                      "Watch your footage at normal speed first, as a viewer would. Then slow it down to find the counts that need cleaning.")
            ],
            takeaway: "One run for accuracy. One run for performance."),
        DanceNote(
            id: "warmup", category: "Care", title: "Warm up, cool down.", shortTitle: "Warm-up",
            summary: "Prepare your body for repeated run-throughs.", cover: .warmup,
            sections: [
                .init("Raise your temperature",
                      "Spend a few minutes on light movement, such as marching or easy bounces, before you dance full out."),
                .init("Move the joints you use",
                      "Gentle circles for the neck, shoulders, wrists, hips, knees and ankles prepare you for hits, turns and floor work."),
                .init("Know when to stop",
                      "Take breaks, drink water and lower the intensity if you feel strain. Stop if something hurts, and talk to a qualified instructor or health professional if it continues.")
            ],
            takeaway: "A careful, slower run beats an injury that stops practice.")
    ]
}

// Shared entry point for Home and the Practice tab.
struct DanceGuideEntry: View {
    var compact = false
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 18) {
                GuideArtwork(subject: .counts).frame(width: compact ? 72 : 94, height: compact ? 88 : 116)
                VStack(alignment: .leading, spacing: 8) {
                    LocalizedText("Dance notes").font(.stage(.headline))
                        .foregroundStyle(KStepStyle.paper)
                    LocalizedText("\(DanceNote.all.count) short reads · Available offline")
                        .font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Glyph(symbol: .back, size: 14, tint: KStepStyle.accent)
                    .rotationEffect(.degrees(180)).frame(width: 20)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background { StageSurface(tone: .plum) }
                .contentShape(Rectangle())
        }.buttonStyle(PressStyle()).accessibilityIdentifier("danceGuide.open")
    }
}

struct DanceGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var category = "All"
    private let categories = ["All", "Basics", "Practice", "Performance", "Care"]
    private var notes: [DanceNote] {
        DanceNote.all.filter { category == "All" || $0.category == category }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SheetHeading(title: "Dance notes") { dismiss() }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ChoiceStrip(values: categories, selected: category) { category = $0 }
                        if let first = notes.first {
                            NavigationLink(value: first.id) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 20) {
                                        GuideArtwork(subject: first.cover).frame(width: 148, height: 148)
                                        featuredCopy(first).frame(minWidth: 112, maxWidth: .infinity, alignment: .leading)
                                    }
                                    VStack(alignment: .leading, spacing: 14) {
                                        GuideArtwork(subject: first.cover).aspectRatio(1.4, contentMode: .fit)
                                        featuredCopy(first)
                                    }
                                }.padding(14).foregroundStyle(KStepStyle.ink)
                                    .background { StageSurface(tone: .blush) }
                                    .contentShape(Rectangle())
                            }.buttonStyle(PressStyle()).accessibilityIdentifier("danceGuide.\(first.id)")
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : 140), spacing: 16)], alignment: .leading, spacing: 22) {
                            ForEach(Array(notes.dropFirst())) { note in
                                NavigationLink(value: note.id) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        GuideArtwork(subject: note.cover).aspectRatio(1, contentMode: .fit)
                                        LocalizedText(note.shortTitle).font(.stage(.headline))
                                            .fixedSize(horizontal: false, vertical: true)
                                        LocalizedText(note.summary).font(.stage(.caption)).foregroundStyle(KStepStyle.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }.foregroundStyle(KStepStyle.paper).contentShape(Rectangle())
                                }.buttonStyle(PressStyle()).accessibilityIdentifier("danceGuide.\(note.id)")
                            }
                        }
                    }.kstepPage()
                }
            }.kstepScreenBackground().foregroundStyle(KStepStyle.paper)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: String.self) { id in
                    if let note = DanceNote.all.first(where: { $0.id == id }) {
                        DanceNoteReader(note: note)
                    }
                }
        }
    }
    private func featuredCopy(_ note: DanceNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LocalizedText(note.category).font(.stage(.caption, weight: .semibold)).foregroundStyle(KStepStyle.paperSecondary)
            LocalizedText(note.title).font(.stage(.title3, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            LocalizedText(note.summary).font(.stage(.subheadline)).foregroundStyle(KStepStyle.paperSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DanceNoteReader: View {
    let note: DanceNote
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconButton(symbol: .back, label: "Back to dance notes") { dismiss() }
                LocalizedText(note.category).font(.stage(.subheadline, weight: .semibold))
                    .foregroundStyle(KStepStyle.secondary)
                Spacer(minLength: 0)
            }.padding(.horizontal, 16).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    GuideArtwork(subject: note.cover).aspectRatio(1, contentMode: .fit).frame(maxWidth: 360)
                    LocalizedText(note.title)
                        .font(.stage(.title2, display: true))
                        .foregroundStyle(KStepStyle.paper).accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(note.sections.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                // The three sections are read in order: counts 1–3 of the note.
                                Text(verbatim: "\(index + 1)").font(.stage(.subheadline, weight: .black)).monospacedDigit()
                                    .foregroundStyle(KStepStyle.accent).accessibilityHidden(true)
                                LocalizedText(note.sections[index].title).font(.stage(.headline))
                                    .accessibilityAddTraits(.isHeader)
                            }
                            LocalizedText(note.sections[index].body).font(.stage(.body)).lineSpacing(5)
                                .foregroundStyle(KStepStyle.paper.opacity(0.9))
                                .textSelection(.enabled)
                        }.fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        LocalizedText("One thing to remember").font(.stage(.caption, weight: .bold))
                        LocalizedText(note.takeaway).font(.stage(.body, weight: .medium)).lineSpacing(3)
                    }.foregroundStyle(KStepStyle.ink)
                        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                        .background { StageSurface(tone: .blush) }
                }.kstepPage()
            }
        }.kstepScreenBackground().foregroundStyle(KStepStyle.paper)
            .toolbar(.hidden, for: .navigationBar)
    }
}
