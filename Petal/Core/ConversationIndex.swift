import Foundation

/// A display cache per profile. Hermes remains the source of truth.
struct ConversationIndex: Codable, Sendable {
    private var profiles: [String: [Conversation]]

    init(legacy: [Conversation] = []) {
        profiles = Dictionary(grouping: legacy, by: \.profile)
    }

    subscript(profile: String) -> [Conversation] { profiles[profile] ?? [] }

    mutating func update(_ rows: [Conversation], profile: String) {
        profiles[profile] = rows.filter { $0.profile == profile }
    }

    /// Marks a conversation as just used so it moves to the top before the next refresh.
    mutating func touch(_ id: String, profile: String, at date: Date = Date()) {
        guard var rows = profiles[profile], let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].updated = max(rows[index].updated, date)
        rows[index].rank = (rows.compactMap(\.rank).min() ?? 0) - 1
        profiles[profile] = rows
    }

    /// Builds rows from `session.list` (ordered by last activity, but carrying only `started_at`).
    /// - `lastActive`: real activity times by session id, from the dashboard listing.
    /// - `known`: the previous rows, so a local bump from the last few minutes isn't undone
    ///   by a server that hasn't caught up yet.
    static func rows(from sessionList: [JSONValue], profile: String, lastActive: [String: Date],
                     known: [Conversation], now: Date = Date()) -> [Conversation] {
        sessionList.enumerated().map { index, row in
            var conversation = Conversation(row, profile: profile)
            conversation.rank = index
            if let date = lastActive[row["id"].string] ?? lastActive[conversation.id] { conversation.updated = max(conversation.updated, date) }
            if let previous = known.first(where: { $0.id == conversation.id }), previous.updated > conversation.updated,
               now.timeIntervalSince(previous.updated) < 300 {
                conversation.updated = previous.updated
                conversation.rank = -1
            }
            return conversation
        }
    }

    /// Activity times from the dashboard's `GET /api/sessions?order=recent` response.
    static func lastActivity(from response: JSONValue) -> [String: Date] {
        var dates: [String: Date] = [:]
        for row in response["sessions"].array {
            let timestamp = max(row["last_active"].double, row["started_at"].double)
            if timestamp > 0, !row["id"].string.isEmpty { dates[row["id"].string] = Date(timeIntervalSince1970: timestamp) }
        }
        return dates
    }

    /// Hermes' order (already by last activity) first, then the most recent date.
    /// Dates alone can't be trusted: without the dashboard listing only `started_at` is known.
    static func ordered(_ rows: [Conversation]) -> [Conversation] {
        rows.sorted { ($0.rank ?? .max, -$0.updated.timeIntervalSince1970) < ($1.rank ?? .max, -$1.updated.timeIntervalSince1970) }
    }
}
