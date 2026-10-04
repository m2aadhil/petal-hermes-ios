import XCTest

/// Pin the UI language so label-based queries are deterministic regardless of the simulator's locale.
private let englishLocale = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

@MainActor
final class PetalUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    func testChatAndAgents() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"] + englishLocale
        app.launch()
        XCTAssertTrue(app.textFields["chat-composer"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertGreaterThan(app.buttons["app-navigation"].frame.minY, app.windows.firstMatch.frame.maxY - 130)
        XCTAssertLessThan(app.windows.firstMatch.frame.maxY - app.textFields["chat-composer"].frame.maxY, 130)
        XCTAssertGreaterThan(app.buttons["quick-agents"].frame.minY, app.textFields["chat-composer"].frame.maxY)
        assertControlsInsideComposer(in: app)
        capture("01-chat")
        openNavigation("Agents", in: app)
        XCTAssertTrue(app.staticTexts["Your agents."].waitForExistence(timeout: 3))
        capture("02-agents")
        app.buttons.containing(.staticText, identifier: "Atlas").firstMatch.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Hello, I’m Atlas")).firstMatch.waitForExistence(timeout: 3))
        openNavigation("Settings", in: app)
        XCTAssertTrue(app.buttons["close-settings"].waitForExistence(timeout: 3))
        capture("03-settings")
        app.buttons["close-settings"].tap()
        XCTAssertTrue(app.textFields["chat-composer"].waitForExistence(timeout: 3))
    }

    func testAttachmentsMenuAndVoicePreserveDraft() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"] + englishLocale
        app.launch()
        let composer = app.textFields["chat-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap(); composer.typeText("Mon brouillon écrit")
        app.buttons["message-actions"].tap()
        XCTAssertTrue(app.buttons["Add a photo"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add a file"].exists)
        XCTAssertFalse(app.buttons["Mention an agent"].exists)
        XCTAssertFalse(app.buttons["Dictate a message"].exists)
        capture("18-attachments-menu")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 30, dy: 150)).tap()
        app.buttons["voice-mode"].tap()
        XCTAssertTrue(app.buttons["voice-listen"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["voice-listen"].isEnabled)
        capture("19-voice")
        app.buttons["return-to-chat"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 3))
        XCTAssertEqual(composer.value as? String, "Mon brouillon écrit")
    }

    func testOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--demo-onboarding"] + englishLocale
        app.launch()
        XCTAssertTrue(app.buttons["Meet my Hermes"].waitForExistence(timeout: 10))
        capture("04-welcome")
        app.buttons["Meet my Hermes"].tap()
        XCTAssertTrue(app.textFields["Hermes address"].waitForExistence(timeout: 3))
        capture("05-connect")
        XCTAssertFalse(app.buttons["connect-agent"].isEnabled)
    }

    func testDraftSurvivesThumbNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"] + englishLocale
        app.launch()
        let composer = app.textFields["chat-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap(); composer.typeText("Mon brouillon reste ici")
        assertControlsInsideComposer(in: app)
        capture("13-composer-keyboard")
        openNavigation("Agents", in: app)
        XCTAssertTrue(app.buttons["return-to-chat"].waitForExistence(timeout: 3))
        app.buttons["return-to-chat"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 3))
        XCTAssertEqual(composer.value as? String, "Mon brouillon reste ici")
        openNavigation("Settings", in: app)
        XCTAssertTrue(app.buttons["close-settings"].waitForExistence(timeout: 3))
        app.buttons["close-settings"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 3))
        XCTAssertEqual(composer.value as? String, "Mon brouillon reste ici")
    }

    private func connectFixtureIfNeeded(_ app: XCUIApplication) {
        if app.buttons["Meet my Hermes"].waitForExistence(timeout: 5) {
            app.buttons["Meet my Hermes"].tap()
            let address = app.textFields["Hermes address"]
            XCTAssertTrue(address.waitForExistence(timeout: 3))
            address.tap(); address.typeText("http://127.0.0.1:19119")
            let user = app.textFields["Username"]
            user.tap()
            user.typeText("hermes-ios-test")
            XCTAssertEqual(user.value as? String, "hermes-ios-test")
            let password = app.secureTextFields["Hermes password"]
            password.tap(); password.typeText("hermes-ios-local-fixture")
            app.swipeUp()
            app.buttons["connect-agent"].tap()
            // Servers with several profiles ask which agent to start with.
            let startWithAgent = app.buttons["start-with-agent"]
            let composer = app.textFields["chat-composer"]
            for _ in 0..<40 where !composer.exists {
                if startWithAgent.exists { startWithAgent.tap(); break }
                sleep(1)
            }
            XCTAssertTrue(composer.waitForExistence(timeout: 40))
            // Verify persisted authentication immediately. Relaunch also dismisses iOS'
            // optional password-manager sheet without saving disposable fixture credentials.
            app.terminate(); app.launch()
        }
    }

    func testNativeStreamingMarkdown() throws {
        guard ProcessInfo.processInfo.environment["HERMES_IOS_INTEGRATION"] == "1" else { throw XCTSkip("Requires isolated Hermes fixture") }
        let app = XCUIApplication()
        app.launch()
        connectFixtureIfNeeded(app)
        XCTAssertTrue(app.staticTexts["Connected to Hermes"].waitForExistence(timeout: 40))
        app.buttons["New conversation"].tap()
        let composer = app.textFields["chat-composer"]
        composer.tap(); composer.typeText("HERMES_IOS_MARKDOWN_TEST")
        app.buttons["send-message"].tap()
        let answer = app.descendants(matching: .any).matching(identifier: "assistant-message")
        XCTAssertTrue(answer.matching(NSPredicate(format: "label CONTAINS %@", "Premiers mots reçus")).firstMatch.waitForExistence(timeout: 12))
        XCTAssertFalse(answer.matching(NSPredicate(format: "label CONTAINS %@", "Réponse terminée.")).firstMatch.exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        capture("23-live-stream")
        XCTAssertTrue(answer.matching(NSPredicate(format: "label CONTAINS %@", "Réponse terminée.")).firstMatch.waitForExistence(timeout: 50))
        XCTAssertEqual(answer.count, 1)
        XCTAssertTrue(app.buttons["Copier le code"].exists)
        app.buttons["Copier le code"].tap()
        XCTAssertTrue(app.buttons["Copier le code"].exists)
        capture("24-markdown-chat")
        // Read earlier content without being dragged back down by layout changes.
        app.swipeDown()
        capture("25-markdown-heading")
    }

    func testNativeSendThenImmediatelyBackground() throws {
        guard ProcessInfo.processInfo.environment["HERMES_IOS_INTEGRATION"] == "1" else { throw XCTSkip("Requires isolated Hermes fixture") }
        let app = XCUIApplication()
        app.launchArguments = ["--integration-test"] + englishLocale
        app.launch()
        connectFixtureIfNeeded(app)
        XCTAssertTrue(app.staticTexts["Connected to Hermes"].waitForExistence(timeout: 40))
        app.buttons["New conversation"].tap()
        let composer = app.textFields["chat-composer"]
        composer.tap(); composer.typeText("HERMES_IOS_BACKGROUND_TEST")
        app.buttons["send-message"].tap()
        // Leave before waiting for either the submission acknowledgement or a first token.
        XCUIDevice.shared.press(.home)
        // Longer than the native 20-second orphan grace. The fixture streams for ~30 seconds.
        sleep(40)
        app.activate()
        let final = app.descendants(matching: .any).matching(identifier: "assistant-message").matching(NSPredicate(format: "label CONTAINS %@", "le fil est retrouvé."))
        XCTAssertTrue(final.firstMatch.waitForExistence(timeout: 45))
        XCTAssertEqual(final.count, 1)
        let sent = app.descendants(matching: .any).matching(identifier: "user-message").matching(NSPredicate(format: "label CONTAINS %@", "HERMES_IOS_BACKGROUND_TEST"))
        XCTAssertEqual(sent.count, 1)
        capture("22-background-completed")
        app.terminate(); app.launch()
        XCTAssertTrue(final.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Connected to Hermes"].waitForExistence(timeout: 40))
    }

    func testNativeHermesConnectionAndResume() throws {
        guard ProcessInfo.processInfo.environment["HERMES_IOS_INTEGRATION"] == "1" else { throw XCTSkip("Start the isolated Hermes integration server and set HERMES_IOS_INTEGRATION=1.") }
        let app = XCUIApplication()
        app.launchArguments = ["--integration-test", "--voice-fixture"] + englishLocale
        app.launch()
        connectFixtureIfNeeded(app)
        XCTAssertTrue(app.textFields["chat-composer"].waitForExistence(timeout: 40))
        XCTAssertTrue(app.staticTexts["Connected to Hermes"].waitForExistence(timeout: 40))
        openNavigation("Conversations", in: app)
        let newChat = try XCTUnwrap(app.buttons.matching(identifier: "New conversation").allElementsBoundByIndex.first(where: { $0.isHittable }))
        newChat.tap()
        let composer = app.textFields["chat-composer"]
        composer.tap(); composer.typeText("Bonjour depuis Petal sur iPhone")
        app.buttons["send-message"].tap()
        let answer = app.descendants(matching: .any).matching(identifier: "assistant-message").matching(NSPredicate(format: "label CONTAINS %@", "Bonjour depuis Hermes"))
        XCTAssertTrue(answer.firstMatch.waitForExistence(timeout: 45))
        XCUIDevice.shared.press(.home)
        // The agent keeps running on Hermes while iOS suspends its client.
        sleep(3)
        app.activate()
        let final = app.descendants(matching: .any).matching(identifier: "assistant-message").matching(NSPredicate(format: "label CONTAINS %@", "le fil est retrouvé."))
        XCTAssertTrue(final.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(final.count, 1)
        capture("06-live-hermes")
        app.terminate(); app.launch()
        XCTAssertTrue(final.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Connected to Hermes"].waitForExistence(timeout: 30))

        // check_tools_contract.py seeds only the disposable research profile.
        app.buttons["quick-agents"].tap()
        XCTAssertTrue(app.buttons["quick-profile-research"].waitForExistence(timeout: 5))
        app.buttons["quick-profile-research"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        openNavigation("Skills", in: app)
        let skill = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "mobile-fixture-")).firstMatch
        XCTAssertTrue(skill.waitForExistence(timeout: 15))
        skill.tap()
        let toggle = app.switches["Available to the agent"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        capture("09-skill-before")
        let expected = (toggle.value as? String) == "1" ? "0" : "1"
        // SwiftUI exposes the label and switch as one wide accessibility element.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: toggle)
        let outcome = XCTWaiter.wait(for: [enabled], timeout: 10)
        capture("09-native-skill")
        XCTAssertEqual(outcome, .completed)
        app.buttons["return-to-chat"].tap()
        openNavigation("Models", in: app)
        XCTAssertTrue(app.staticTexts["hermes-ios-fixture-mobile"].firstMatch.waitForExistence(timeout: 20))
        app.buttons["return-to-chat"].tap()
        openNavigation("Workspace", in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Mobile ")).firstMatch.waitForExistence(timeout: 15))
        app.buttons["return-to-chat"].tap()
        openNavigation("Kanban", in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Mobile fixture ")).firstMatch.waitForExistence(timeout: 15))
        capture("10-native-kanban")
        app.buttons["return-to-chat"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap(); composer.typeText("Brouillon préservé pendant la voix")
        app.buttons["voice-mode"].tap()
        XCTAssertTrue(app.staticTexts["Bonjour Hermes, résume mon projet."].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Hermes is answering."].waitForExistence(timeout: 45))
        XCTAssertTrue(app.staticTexts["I’m listening."].waitForExistence(timeout: 15))
        capture("20-native-voice-loop")
        app.buttons["return-to-chat"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertEqual(composer.value as? String, "Brouillon préservé pendant la voix")
    }

    func testSpacesDiscoveryAndTools() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"] + englishLocale
        app.launch()
        XCTAssertTrue(app.buttons["app-navigation"].waitForExistence(timeout: 10))
        app.buttons["app-navigation"].tap()
        XCTAssertTrue(app.textFields["spaces-search"].waitForExistence(timeout: 3))
        capture("07-spaces")
        XCTAssertTrue(app.buttons["space-kanban"].exists)
        XCTAssertFalse(app.buttons["space-skills"].exists)
        app.buttons["tools-filter-agent"].tap()
        XCTAssertTrue(app.buttons["space-skills"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["space-kanban"].exists)
        capture("11-agent-tools")
        for (query, identifier, title) in [("cron", "routines", "Routines"), ("skills", "skills", "Skills"), ("kanban", "kanban", "Kanban"), ("workspace", "workspace", "Workspace"), ("model", "models", "Models"), ("voice", "voice", "Voice")] {
            let search = app.textFields["spaces-search"]
            search.tap(); search.typeText(query)
            let button = app.buttons["space-" + identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 3))
            button.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3))
            if identifier == "voice" {
                XCTAssertTrue(app.buttons["voice-listen"].exists)
                XCTAssertEqual(app.buttons["voice-listen"].frame.midY, app.buttons["return-to-chat"].frame.midY, accuracy: 1)
            }
            if identifier == "kanban" {
                XCTAssertTrue(app.buttons["New task"].exists)
                XCTAssertLessThanOrEqual(app.buttons["New task"].frame.maxY, app.buttons["return-to-chat"].frame.maxY)
            }
            capture("08-" + identifier)
            if identifier == "kanban" { XCTAssertTrue(app.staticTexts["Prepare the next idea"].waitForExistence(timeout: 5)) }
            app.buttons["back-to-spaces"].tap()
            XCTAssertTrue(app.textFields["spaces-search"].waitForExistence(timeout: 3))
            app.buttons["Effacer la recherche"].tap()
        }
        app.buttons["return-to-chat"].tap()
        XCTAssertTrue(app.textFields["chat-composer"].waitForExistence(timeout: 3))
    }

    private func openNavigation(_ destination: String, in app: XCUIApplication) {
        if destination == "Agents" {
            app.buttons["quick-agents"].tap()
            XCTAssertTrue(app.buttons["manage-agents"].waitForExistence(timeout: 3))
            app.buttons["manage-agents"].tap(); return
        }
        if destination == "Conversations" { app.buttons["quick-history"].tap(); return }
        app.buttons["app-navigation"].tap()
        if destination == "Settings" {
            XCTAssertTrue(app.buttons["quick-settings"].waitForExistence(timeout: 3))
            app.buttons["quick-settings"].tap(); return
        }
        let search = app.textFields["spaces-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap(); search.typeText(destination)
        let identifier = destination == "Settings" ? "settings" : destination == "Models" ? "models" : destination == "Conversations" ? "history" : destination.lowercased()
        let button = app.buttons["space-" + identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        button.tap()
    }

    func testQuickProfileSwitchKeepsSeparateDrafts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"] + englishLocale
        app.launch()
        let composer = app.textFields["chat-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap(); composer.typeText("Une idee pour Hermes")
        app.buttons["quick-agents"].tap()
        XCTAssertTrue(app.buttons["quick-profile-default"].waitForExistence(timeout: 3))
        capture("12-profiles")
        // Selecting the active profile must leave the current chat untouched.
        app.buttons["quick-profile-default"].tap()
        XCTAssertEqual(composer.value as? String, "Une idee pour Hermes")
        app.buttons["quick-agents"].tap()
        app.buttons["quick-profile-research"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Hello, I’m Atlas")).firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(composer.value as? String, "Message…")
        composer.tap(); composer.typeText("Une recherche pour Atlas")
        app.buttons["quick-agents"].tap()
        app.buttons["quick-profile-default"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 3))
        XCTAssertEqual(composer.value as? String, "Une idee pour Hermes")
        app.buttons["quick-agents"].tap()
        app.buttons["quick-profile-research"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 3))
        XCTAssertEqual(composer.value as? String, "Une recherche pour Atlas")
        app.buttons["quick-history"].tap()
        XCTAssertTrue(app.navigationBars["Conversations"].waitForExistence(timeout: 3))
        capture("21-conversation-list")
        app.buttons["return-to-chat"].tap()
        XCTAssertEqual(composer.value as? String, "Une recherche pour Atlas")
    }

    // MARK: Chat scrolling
    //
    // `--demo-long-chat` opens a 40-message conversation whose last reply has reasoning.
    // The demo also runs the in-memory autosave on every keystroke, like a connected app.

    func testTypingKeepsTheLatestReplyOnScreen() throws {
        let app = launchLongChat()
        let composer = app.textFields["chat-composer"]
        let latest = message("assistant-message", containing: "just one thing", in: app)
        XCTAssertTrue(eventually(5) { self.isOnScreen(latest, in: app) }, "the chat should open on its latest reply")

        composer.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(eventually { self.isOnScreen(latest, in: app) }, "the keyboard must not hide the latest reply")

        let words = "This draft is long enough to wrap onto several lines while I keep typing "
        for chunk in 1...6 {
            composer.typeText(words)
            pause(0.6) // longer than the autosave interval
            if !isOnScreen(latest, in: app) { capture("typing-latest-hidden-\(chunk)") }
            XCTAssertGreaterThan(visibleMessageCount(in: app), 0, "the chat went blank after chunk \(chunk)")
            XCTAssertTrue(isOnScreen(latest, in: app), "the latest reply scrolled away after chunk \(chunk)")
        }
        capture("30-typing-long-draft")
    }

    func testTypingWhileScrolledUpKeepsThePlace() throws {
        let app = launchLongChat()
        let composer = app.textFields["chat-composer"]
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        scroll.swipeDown(); scroll.swipeDown()
        pause(1)

        let visible = messages(in: app).filter { isOnScreen($0, in: app) }
        let reference = try XCTUnwrap(visible.first, "no message on screen after scrolling up")
        let label = reference.label
        let pinned = message(withLabel: label, in: app)
        let before = pinned.frame.minY

        composer.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        for chunk in 1...4 {
            composer.typeText("Reading older replies while I draft a follow-up question ")
            pause(0.6)
            XCTAssertGreaterThan(visibleMessageCount(in: app), 0, "the chat went blank after chunk \(chunk)")
            XCTAssertTrue(isOnScreen(pinned, in: app), "the message being read disappeared after chunk \(chunk)")
        }
        XCTAssertEqual(pinned.frame.minY, before, accuracy: 60, "typing must not scroll the history being read")
        capture("31-typing-scrolled-up")
    }

    func testExpandingThinkingOpensInPlace() throws {
        let app = launchLongChat()
        let toggle = app.buttons["thinking-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(eventually { self.isOnScreen(toggle, in: app) })
        let before = toggle.frame.minY

        toggle.tap()
        let thinking = app.descendants(matching: .any)["thinking-text"]
        XCTAssertTrue(thinking.waitForExistence(timeout: 2))
        pause(0.8)
        XCTAssertTrue(isOnScreen(toggle, in: app), "the Thinking toggle scrolled away after expanding")
        XCTAssertEqual(toggle.frame.minY, before, accuracy: 30, "Thinking should open where it was tapped")
        XCTAssertTrue(isOnScreen(thinking, in: app))
        capture("32-thinking-expanded")

        toggle.tap()
        XCTAssertTrue(eventually { !thinking.exists }, "Thinking should collapse again")
    }

    func testOpeningAChatLandsOnItsLatestReply() throws {
        // Cached chat first, then the server's (shorter) copy of the same messages.
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--demo-long-chat", "--demo-delayed-history"] + englishLocale
        app.launch()
        XCTAssertTrue(app.textFields["chat-composer"].waitForExistence(timeout: 10))
        pause(2) // both loads have landed
        let latest = message("assistant-message", containing: "make some room", in: app)
        if !isOnScreen(latest, in: app) { capture("33-open-latest-hidden") }
        XCTAssertGreaterThan(visibleMessageCount(in: app), 0, "the chat opened on an empty screen")
        XCTAssertTrue(isOnScreen(latest, in: app), "the chat should open on its latest reply")
    }

    private func launchLongChat() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--demo-long-chat"] + englishLocale
        app.launch()
        XCTAssertTrue(app.textFields["chat-composer"].waitForExistence(timeout: 10))
        return app
    }

    private func messages(in app: XCUIApplication) -> [XCUIElement] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@", ["assistant-message", "user-message"]))
            .allElementsBoundByIndex
    }

    private func message(_ identifier: String, containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier)
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func message(withLabel label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@ AND label == %@", ["assistant-message", "user-message"], label)).firstMatch
    }

    /// The area between the chat header and the composer.
    private func chatViewport(in app: XCUIApplication) -> CGRect {
        let top = app.buttons["quick-agents"].frame.maxY
        let bottom = app.otherElements["composer-surface"].frame.minY
        return CGRect(x: 0, y: top, width: app.frame.width, height: max(0, bottom - top))
    }

    /// At least 16 pt of the element is visible in the chat area.
    private func isOnScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, !element.frame.isEmpty else { return false }
        return element.frame.intersection(chatViewport(in: app)).height >= 16
    }

    private func visibleMessageCount(in app: XCUIApplication) -> Int {
        messages(in: app).filter { isOnScreen($0, in: app) }.count
    }

    private func eventually(_ timeout: TimeInterval = 3, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            pause(0.1)
        } while Date() < end
        return condition()
    }

    private func pause(_ seconds: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        // Also keep PNGs in the disposable runner container: beta Xcode can stall
        // while finalizing xcresult after a fully completed suite.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("hermes-ios-qa")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertControlsInsideComposer(in app: XCUIApplication) {
        let surface = app.otherElements["composer-surface"]
        XCTAssertTrue(surface.exists)
        for identifier in ["message-actions", "quick-history", "app-navigation", "voice-mode", "send-message"] {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.exists)
            XCTAssertTrue(surface.frame.contains(control.frame), "\(identifier) belongs inside the composer bubble")
        }
    }
}
