import Foundation
import Combine

// Manual rehearsal log: the dancer records each run-through between takes.
// Nothing here analyses video; every value comes from the dancer's own entry.

enum SongSection: String, Codable, CaseIterable, Identifiable {
    case intro, verse, preChorus, chorus, danceBreak, bridge, outro
    var id: String { rawValue }
    var label: String {
        switch self {
        case .intro: "Intro"; case .verse: "Verse"; case .preChorus: "Pre-chorus"; case .chorus: "Chorus"
        case .danceBreak: "Dance break"; case .bridge: "Bridge"; case .outro: "Outro"
        }
    }
}

enum PracticeTempo: String, Codable, CaseIterable, Identifiable {
    case half, threeQuarters, full
    var id: String { rawValue }
    var label: String {
        switch self { case .half: "0.5×"; case .threeQuarters: "0.75×"; case .full: "1×" }
    }
    var csvValue: String {
        switch self { case .half: "0.5"; case .threeQuarters: "0.75"; case .full: "1.0" }
    }
}

enum RunResult: String, Codable, CaseIterable, Identifiable {
    case clean, almost, lostCount, forgotMoves
    var id: String { rawValue }
    var label: String {
        switch self { case .clean: "Clean run"; case .almost: "Almost there"; case .lostCount: "Lost the count"; case .forgotMoves: "Forgot the moves" }
    }
    var isClean: Bool { self == .clean }
}

struct DanceRun: Codable, Identifiable {
    let id: UUID
    let recordedAt: Date
    let section: SongSection
    let eightCount: Int // 1...8: which eight-count of the section was drilled.
    let tempo: PracticeTempo
    let mirrored: Bool
    let result: RunResult
    let note: String?
}

struct DancePracticeSession: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    var finishedAt: Date?
    var routine: String
    var runs: [DanceRun]
    var cleanCount: Int { runs.filter { $0.result.isClean }.count }
    var fullSpeedCleanCount: Int { runs.filter { $0.result.isClean && $0.tempo == .full }.count }
    var sectionsDrilled: Int { Set(runs.map(\.section)).count }
}

private struct DanceJournalArchive: Codable {
    var activeSession: DancePracticeSession?
    var completedSessions: [DancePracticeSession] = []
}

@MainActor
final class DancePracticeJournal: ObservableObject {
    @Published private var archive = DanceJournalArchive()
    @Published private(set) var storageMessage: String?
    private let archiveURL: URL
    private var storageReadable = true
    var activeSession: DancePracticeSession? { archive.activeSession }
    var completedSessions: [DancePracticeSession] { archive.completedSessions }
    var available: Bool { storageReadable }

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DancePractice", isDirectory: true)
        archiveURL = folder.appendingPathComponent("sessions.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                archive = try JSONDecoder().decode(DanceJournalArchive.self, from: Data(contentsOf: archiveURL))
            }
        } catch {
            storageReadable = false
            storageMessage = "Practice records could not be opened. Existing records are preserved."
        }
    }

    func beginSession(routine: String) {
        guard activeSession == nil else { return }
        var next = archive
        next.activeSession = DancePracticeSession(id: UUID(), startedAt: Date(),
                                                  routine: routine.trimmingCharacters(in: .whitespacesAndNewlines), runs: [])
        commit(next)
    }

    func record(_ result: RunResult, section: SongSection, eightCount: Int, tempo: PracticeTempo,
                mirrored: Bool, note: String?) -> Bool {
        guard var session = activeSession, (1...8).contains(eightCount) else { return false }
        session.runs.append(DanceRun(id: UUID(), recordedAt: Date(), section: section, eightCount: eightCount,
                                     tempo: tempo, mirrored: mirrored, result: result, note: note?.nilIfBlank))
        var next = archive
        next.activeSession = session
        return commit(next)
    }

    func undoLastRun() {
        guard var session = activeSession, !session.runs.isEmpty else { return }
        session.runs.removeLast()
        var next = archive
        next.activeSession = session
        commit(next)
    }

    func finishSession() {
        guard var session = activeSession else { return }
        var next = archive
        if !session.runs.isEmpty {
            session.finishedAt = Date()
            next.completedSessions.insert(session, at: 0)
        }
        next.activeSession = nil
        commit(next)
    }

    func removeSession(_ sessionID: UUID) {
        var next = archive
        next.completedSessions.removeAll { $0.id == sessionID }
        commit(next)
    }

    func exportSession(_ session: DancePracticeSession) -> URL? {
        // Stable, documented English column names for spreadsheet interoperability.
        let dates = ISO8601DateFormatter()
        var lines = ["recorded_at_utc,routine,section,eight_count,practice_speed,mirrored,result,note"]
        lines += session.runs.map {
            [dates.string(from: $0.recordedAt), Self.csvField(session.routine), $0.section.rawValue,
             String($0.eightCount), $0.tempo.csvValue, $0.mirrored ? "true" : "false", $0.result.rawValue,
             Self.csvField($0.note ?? "")]
                .joined(separator: ",")
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DanceExports", isDirectory: true)
        let url = folder.appendingPathComponent("dance-practice-\(session.id.uuidString).csv")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: url, options: .atomic)
            return url
        } catch { storageMessage = "The practice export could not be created. Please try again."; return nil }
    }

    // RFC 4180 quoting; neutralise leading formula characters from free text.
    private static func csvField(_ value: String) -> String {
        var text = value.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " ")
        if let first = text.first, "=+-@".contains(first) { text = "'" + text }
        guard text.contains(where: { $0 == "," || $0 == "\"" }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    @discardableResult
    private func commit(_ next: DanceJournalArchive) -> Bool {
        guard storageReadable else { return false }
        do {
            let data = try JSONEncoder().encode(next)
            try data.write(to: archiveURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            archive = next
            storageMessage = nil
            return true
        } catch {
            storageMessage = "This change could not be saved. Please try again."
            return false
        }
    }
}
