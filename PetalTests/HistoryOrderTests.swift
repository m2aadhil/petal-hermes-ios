import XCTest
@testable import PetalCore

final class HistoryOrderTests: XCTestCase {
    private func row(_ id: String, started: Double, rank: Int, lastActive: Double? = nil) -> Conversation {
        var fields: [String: JSONValue] = ["id": .string(id), "title": .string(id), "started_at": .number(started)]
        if let lastActive { fields["last_active"] = .number(lastActive) }
        var conversation = Conversation(.object(fields), profile: "default")
        conversation.rank = rank
        return conversation
    }

    func testLastActivityWinsOverCreationDate() {
        // "old" was created first but used most recently.
        let rows = [row("new", started: 200, rank: 1), row("old", started: 100, rank: 0, lastActive: 300)]
        XCTAssertEqual(ConversationIndex.ordered(rows).map(\.id), ["old", "new"])
    }

    func testHermesOrderDecides() {
        let rows = [row("b", started: 100, rank: 1), row("a", started: 100, rank: 0)]
        XCTAssertEqual(ConversationIndex.ordered(rows).map(\.id), ["a", "b"])
    }

    func testTouchMovesAConversationToTheTop() {
        var index = ConversationIndex()
        index.update([row("a", started: 300, rank: 0), row("b", started: 100, rank: 1)], profile: "default")
        index.touch("b", profile: "default", at: Date(timeIntervalSince1970: 400))
        XCTAssertEqual(ConversationIndex.ordered(index["default"]).map(\.id), ["b", "a"])
    }

    func testSessionListIsDatedWithDashboardActivity() {
        // session.list: most recent first, only started_at. "old" was started first but used today.
        let list: [JSONValue] = [
            ["id": "old", "title": "Old", "started_at": 100],
            ["id": "new", "title": "New", "started_at": 200]
        ]
        let dashboard: JSONValue = ["sessions": [["id": "old", "started_at": 100, "last_active": 500],
                                                 ["id": "new", "started_at": 200, "last_active": 250]]]
        let rows = ConversationIndex.rows(from: list, profile: "default", lastActive: ConversationIndex.lastActivity(from: dashboard), known: [])
        XCTAssertEqual(rows.map(\.rank), [0, 1])
        XCTAssertEqual(rows.map(\.updated.timeIntervalSince1970), [500, 250])
        XCTAssertEqual(ConversationIndex.ordered(rows).map(\.id), ["old", "new"])
    }

    func testWithoutDashboardDatesHermesOrderStillWins() {
        // Only started_at is known: "new" has the later start, but Hermes ranks "old" first.
        let list: [JSONValue] = [["id": "old", "started_at": 100], ["id": "new", "started_at": 200]]
        let rows = ConversationIndex.rows(from: list, profile: "default", lastActive: [:], known: [])
        XCTAssertEqual(rows.map(\.rank), [0, 1])
        XCTAssertEqual(ConversationIndex.ordered(rows).map(\.id), ["old", "new"])
    }

    func testRecentLocalBumpSurvivesAStaleRefresh() {
        let now = Date(timeIntervalSince1970: 1_000)
        var bumped = row("b", started: 100, rank: 1)
        bumped.updated = Date(timeIntervalSince1970: 990) // sent a message 10 s ago
        let list: [JSONValue] = [["id": "a", "started_at": 300], ["id": "b", "started_at": 100]]
        let rows = ConversationIndex.rows(from: list, profile: "default", lastActive: ["a": Date(timeIntervalSince1970: 300)], known: [bumped], now: now)
        XCTAssertEqual(ConversationIndex.ordered(rows).map(\.id), ["b", "a"])

        // Ten minutes later the server's answer is trusted again.
        let later = ConversationIndex.rows(from: list, profile: "default", lastActive: ["a": Date(timeIntervalSince1970: 1_500)],
                                           known: [bumped], now: Date(timeIntervalSince1970: 1_600))
        XCTAssertEqual(ConversationIndex.ordered(later).map(\.id), ["a", "b"])
    }

    func testIgnoresUnusableDashboardRows() {
        let dates = ConversationIndex.lastActivity(from: ["sessions": [["id": "", "last_active": 5], ["id": "x"], ["id": "y", "last_active": 9]]])
        XCTAssertEqual(dates.keys.sorted(), ["y"])
    }
}
