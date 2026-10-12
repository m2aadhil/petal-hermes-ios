import XCTest
@testable import PetalCore

final class ThinkingTests: XCTestCase {
    func testStreamedReasoningAttachesToTheReplyAndIsTimed() throws {
        var transcript = Transcript()
        transcript.apply(event(1, "message.start"))
        transcript.apply(event(2, "reasoning.delta", text: "Let me "))
        transcript.apply(event(3, "reasoning.delta", text: "check."))
        XCTAssertEqual(transcript.messages.count, 1)
        XCTAssertEqual(transcript.messages[0].reasoning, "Let me check.")
        XCTAssertEqual(transcript.messages[0].text, "")
        XCTAssertNil(transcript.messages[0].thinkingSeconds)

        transcript.apply(event(4, "message.delta", text: "Answer"))
        let seconds = try XCTUnwrap(transcript.messages[0].thinkingSeconds)
        XCTAssertGreaterThanOrEqual(seconds, 0)
        transcript.apply(event(5, "message.complete", text: "Answer"))
        XCTAssertEqual(transcript.messages.map(\.text), ["Answer"])
        XCTAssertEqual(transcript.messages[0].reasoning, "Let me check.")
    }

    func testSecondReasoningPassStartsANewParagraph() {
        var transcript = Transcript()
        transcript.apply(event(1, "reasoning.delta", text: "First."))
        transcript.apply(event(2, "message.delta", text: "Checking…"))
        transcript.apply(event(3, "reasoning.delta", text: "Second."))
        XCTAssertEqual(transcript.messages[0].reasoning, "First.\n\nSecond.")
    }

    func testCompletedReasoningBlockIsNotDuplicated() {
        var transcript = Transcript()
        transcript.apply(event(1, "reasoning.delta", text: "Same thought"))
        transcript.apply(event(2, "reasoning.available", text: "Same thought"))
        XCTAssertEqual(transcript.messages[0].reasoning, "Same thought")
    }

    func testReasoningOnlyTurnIsKeptWhenCompleteHasNoText() {
        var transcript = Transcript()
        transcript.apply(event(1, "reasoning.delta", text: "Thinking hard"))
        transcript.apply(event(2, "message.complete"))
        XCTAssertEqual(transcript.messages.count, 1)
        XCTAssertFalse(transcript.messages[0].streaming)
    }

    func testSpinnerTextIsNotTreatedAsReasoning() {
        var transcript = Transcript()
        transcript.apply(event(1, "thinking.delta", text: "(◕‿◕) pondering"))
        XCTAssertTrue(transcript.messages.isEmpty)
        XCTAssertTrue(transcript.running)
    }

    func testHistoryReasoningFromToolStepsJoinsTheFollowingReply() {
        var transcript = Transcript()
        transcript.hydrate(["messages": [
            ["role": "user", "text": "Question"],
            ["role": "assistant", "text": "", "reasoning": "Need a tool."],
            ["role": "tool", "name": "terminal"],
            ["role": "assistant", "text": "Answer", "reasoning_content": "Tool said yes."],
            ["role": "user", "text": "Thanks"],
            ["role": "assistant", "text": "Welcome"]
        ]])
        XCTAssertEqual(transcript.messages.map(\.text), ["Question", "Answer", "Thanks", "Welcome"])
        XCTAssertEqual(transcript.messages[1].reasoning, "Need a tool.\n\nTool said yes.")
        XCTAssertNil(transcript.messages[3].reasoning)
        XCTAssertNil(transcript.messages[0].reasoning)
    }

    func testLiveReasoningSurvivesRehydrationWithoutHistoryReasoning() {
        var transcript = Transcript()
        transcript.apply(event(1, "reasoning.delta", text: "Live thought"))
        transcript.apply(event(2, "message.complete", text: "Reply"))
        transcript.hydrate(["messages": [["role": "assistant", "text": "Reply"]]])
        XCTAssertEqual(transcript.messages[0].reasoning, "Live thought")
        XCTAssertNotNil(transcript.messages[0].thinkingSeconds)
    }

    private func event(_ seq: Int, _ type: String, text: String = "") -> JSONValue {
        ["session_id": "runtime", "seq": .number(Double(seq)), "type": .string(type), "payload": ["text": .string(text)]]
    }
}
