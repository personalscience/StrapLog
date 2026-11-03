import Foundation

/// A free-text marker note used before, with the activities it was used in.
public struct RecentNote: Sendable, Hashable {
    public let text: String
    /// `ActivityPreset.id`s of the recordings that used it.
    public let activities: Set<String>

    public init(text: String, activities: Set<String>) {
        self.text = text
        self.activities = activities
    }

    /// `notes` (most recent first) that match `query`, best first: notes starting with the query,
    /// then notes used in `activity`, then the most recent. Every word of the query must start
    /// a word of the note, ignoring case and accents, so `press 13` finds `Shoulder Press 130`.
    /// A query with no words matches everything.
    public static func suggestions(_ notes: [RecentNote], matching query: String, activity: String) -> [String] {
        let folded = fold(query).trimmingCharacters(in: .whitespacesAndNewlines)
        let queryWords = words(folded)
        return notes.enumerated()
            .filter { _, note in
                let noteWords = words(fold(note.text))
                return queryWords.allSatisfy { word in noteWords.contains { $0.hasPrefix(word) } }
            }
            .map { index, note in
                (rank: (fold(note.text).hasPrefix(folded) ? 0 : 1, note.activities.contains(activity) ? 0 : 1, index),
                 text: note.text)
            }
            .sorted { $0.rank < $1.rank }
            .map(\.text)
    }

    /// Merges rows that differ only by case, keeping the first (latest) spelling, and caps at `limit`.
    static func merged(_ rows: [(text: String, activity: String)], limit: Int) -> [RecentNote] {
        var order: [String] = []
        var spelling: [String: String] = [:]
        var activities: [String: Set<String>] = [:]
        for row in rows {
            let key = row.text.lowercased()
            if spelling[key] == nil {
                spelling[key] = row.text
                order.append(key)
            }
            activities[key, default: []].insert(row.activity)
        }
        return order.prefix(limit).map { RecentNote(text: spelling[$0] ?? $0, activities: activities[$0] ?? []) }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func words(_ text: String) -> [Substring] {
        text.split { !$0.isLetter && !$0.isNumber }
    }
}
