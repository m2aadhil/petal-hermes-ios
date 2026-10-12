# AGENTS.md: context for AI coding agents

Read this first. It covers what Petal is, how it's built, the server contract it depends on, the rules
that aren't obvious from the code, and where work stands. Deeper docs live in `docs/`.

## What this is

**Petal** is a native SwiftUI iPhone/iPad client for [Hermes Agent](https://github.com/NousResearch/hermes-agent)
by Nous Research. Users self-host `hermes serve` (often over Tailscale); Petal connects directly to it.
There is no relay, Petal account, analytics or third-party runtime dependency.

- It is a fork of an open-source client that was called "Hermès iOS". The owner (Aadhil) renamed it to Petal.
  Petal is an independent community project and **not an official Nous Research product**. Don't brand
  it as Hermes or imply official status. "Hermes" in the UI always means the user's agent/server.
- Bundle ID: `org.m2aadhil.Petal` (UI tests: `org.m2aadhil.PetalUITests`). Version 0.1.0.
- Languages: English (source) and French. The UI started out hardcoded in French.
- Look: calm, warm, native. Paper-toned backgrounds, one terracotta accent (`#CF4A30`), serif headlines,
  a six-petal mark.

## Stack and layout

- Swift 6 (strict concurrency), SwiftUI, iOS 17.0+, iPhone and iPad. `@Observable` + `@MainActor` app model.
- `project.yml` (XcodeGen) **and** a checked-in `Petal.xcodeproj`. Keep both in sync: when you add a
  Swift file, also add it to `project.pbxproj` (PBXBuildFile, PBXFileReference, group child, Sources
  phase), or run `xcodegen generate`.
- `Package.swift` defines `PetalCore` (= `Petal/Core`, Foundation/ImageIO only) for `swift test`.
  Put pure logic in Core so it can be unit-tested; UI goes in `Petal/Features`.

```
Petal/
  Core/          Pure logic, unit-tested: Transcript (event → messages), Models (ChatMessage, Conversation,
                 ChatSnapshot), ChatMarkdown (block parser + autolinks), ConversationIndex (history order),
                 FileReferences (paths in replies), ImagePreparer (upload compression), JSONValue, Endpoint
  DesignSystem/  Tokens (DS.Palette/Space/Radius/Size/Motion/Elevation), Typography (.textStyle), Components
                 (PrimaryButton, IconButton, SearchField, FormField, ScreenHeader, InlineMessage, .card()…),
                 Brand (mark + wordmark), Gallery (preview of all of it)
  Features/      AppModel (state + all server calls), ChatView (+ MessageView, composer, scroll logic),
                 MarkdownText, ThinkingView, FileChips, OnboardingView, SettingsView, SpacesView (tools
                 drawer), AgentsView (profiles + SessionsView), AgentToolsView (skills/models/workspace),
                 KanbanView, GroupsView, RoutinesView, VoiceView, NativeToolSession
  Networking/    HermesHTTP (REST + auth + downloads), HermesSocket (JSON-RPC over /api/ws), Keychain,
                 LocalCache (Application Support), BackgroundLease
  Resources/     Localizable.xcstrings, InfoPlist.xcstrings, Info.plist, Assets, PrivacyInfo
PetalTests/      XCTest for PetalCore (~70 tests)
PetalUITests/    XCUITest, mostly in demo mode (13 tests)
docs/            ARCHITECTURE, CONNECTING, DESIGN_SYSTEM, HERMES_PROTOCOL, LOCALIZATION, TESTING, VALIDATION
scripts/         build_ipa.sh, integration_server.py (local Hermes fixture), contract checkers
```

## Build, test, ship

These need a Mac with Xcode. The owner builds locally. If you run in a Linux sandbox you **cannot
compile Swift**: say so, keep changes small and careful, and ask the owner to build.

```sh
swift test                                    # PetalCore unit tests
xcodebuild -scheme Petal -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild … -only-testing:PetalUITests/PetalUITests/<testName> test   # one UI test
scripts/build_ipa.sh                          # archive + export build/ipa/Petal.ipa (TEAM_ID, METHOD env vars)
```

- Demo mode needs no server: launch arguments `--demo`, plus `--demo-long-chat` (40 messages with
  reasoning on the last one) and `--demo-delayed-history` (cached chat, then a shorter server copy).
  UI tests also pass `-AppleLanguages (en) -AppleLocale en_US`.
- `HermesIntegration`-style tests (`PetalIntegration` scheme) need `scripts/integration_server.py`; see
  `docs/TESTING.md`.

## Rules that aren't obvious from the code

**Localization**
- Every user-facing string goes in `Localizable.xcstrings` with a French translation
  (`String(localized:)`, `LocalizedStringKey`, or `Text("…")`). Use `Text(verbatim:)` for
  non-translatable text (names, paths, the "Petal" wordmark). Permission prompts are in `InfoPlist.xcstrings`.
- Xcode rewrites the catalog in its own format (`"key" : value`) on build. Keep that format; don't
  reformat the whole file. Insert entries textually and validate the JSON.

**Design system**
- Use `DS.*` tokens and `.textStyle(...)`; no raw colors, fonts or magic numbers. Use `DS.Palette.accentText`
  for accent-colored text (contrast). Respect Dynamic Type and Reduce Motion. Tap targets ≥ `DS.Size.tap`.

**Accessibility identifiers are test API.** Keep existing ones (`chat-composer`, `composer-surface`,
`assistant-message`, `user-message`, `quick-agents`, `quick-history`, `app-navigation`, `thinking-toggle`,
`file-chip`, `start-with-agent`, `stay-signed-in`, …). In `MessageView` the reply text is one combined
element (`assistant-message`); Thinking and file cards stay separate so their buttons are reachable.

**Never change the server's global config by accident.** Hermes `config.set` without `session_id`
writes `config.yaml` for every client. Petal only sets reasoning per session (`config.set reasoning` with
`session_id`, or `reasoning_effort` on `session.create`). It never sends `reasoning show|hide`; hiding
thinking is an app-only setting (`@AppStorage("showThinking")`).

**Credentials.** Cookies and the optional "Stay signed in" username/password live in the Keychain
(service `org.hermesios.credentials`, `AfterFirstUnlockThisDeviceOnly`). The service name and the
`HermesIOS` cache folder are intentionally unchanged from the old name so installed builds keep their
data; don't rename them. `HermesHTTP.request` retries once after a 401 via a single-flight silent sign-in.

**Chat scrolling (fragile, covered by UI tests).** iOS 18: `defaultScrollAnchor(.bottom, for: .initialOffset)`,
`.top` for `.sizeChanges` and `.alignment`. ChatView follows the bottom itself only while a reply streams,
or briefly (`settle()`) after opening, sending, finishing or history loading. It snaps back if the view
sits past the end, re-pins when the visible height changes (keyboard, growing composer), and expanding
Thinking calls `holdChatScroll`. Autosave must not reassign `selected` unless messages changed (it
re-rendered the chat on every keystroke). Run the four scrolling UI tests after touching any of this.

**Git**
- Don't commit the owner's local signing team (`DEVELOPMENT_TEAM = DZ6CYVAH32` in `project.pbxproj`;
  committed value is `""`), `.swiftpm/`, or the leftover `HermesIOS.xcodeproj/` folder.
- Commit only when asked. Work happens on `feature/localization`; origin is `Molliex05/hermes-ios`.

## Hermes server contract (what Petal relies on)

Verified against hermes-agent `main`, late Sept 2026. See `docs/HERMES_PROTOCOL.md`.

- Auth: `POST /auth/password-login` (basic provider, ~12 h fixed TTL, no refresh token; sessions survive
  restarts only with `HERMES_DASHBOARD_BASIC_AUTH_SECRET`). WebSocket via `POST /api/auth/ws-ticket` → `/api/ws`.
- JSON-RPC: `profiles.list`, `session.create {profile, reasoning_effort?}`, `session.list` (ordered by
  last activity, **but rows only carry `started_at`**), `prompt.submit`, `file.attach`/`image.attach`
  (base64 data URLs), `session.events.since` (replay), `config.get/set`.
- Events: `message.start/delta/complete`, `reasoning.delta` / `reasoning.available` (real reasoning, sent
  when `display.show_reasoning` is on, the default), `thinking.delta` (spinner/wait text, **not**
  reasoning), `tool.*`, `approval.*`, `clarify.*`. History rows can carry `reasoning`/`reasoning_content`.
- REST used: `/api/status`, `/api/sessions?order=recent` (gives `last_active`; used to date history),
  `/api/files/download?path=` (any non-credential file, 100 MB cap, locked root if
  `HERMES_DASHBOARD_FILES_ROOT`), `/api/skills*`, `/api/model/*`, `/api/audio/*`.
- Petal sessions get the `tui` platform prompt, which tells the agent there is no attachment channel, so
  it writes plain paths instead of `MEDIA:/path`. Petal handles both.

## Features added in this fork (Sept–Oct 2026)

- English + French localization with String Catalogs; design system in `Petal/DesignSystem`.
- Onboarding: choose which agent profile to start with; "Stay signed in" with silent re-auth.
- Image uploads: `ImagePreparer` caps the long edge at 2048 px, keeps PNG for screenshots/alpha, JPEG
  0.88→0.72 for photos, 4 MB budget, strips EXIF/GPS. HEIC from Files is sent as an image.
- Files from Hermes: paths/`MEDIA:` in replies become cards; tap downloads and opens Quick Look.
- Thinking: live "Thinking…" / "Thought for 12 s" disclosure, history reasoning, app-only toggle,
  per-chat level menu (Off/Low/Medium/High) in the chat header.
- History ordered by real last activity (server order is authoritative, dashboard dates, local bump on send).
- Plain URLs in replies are tappable (http/https/mailto only), and links are underlined.
- Chat scrolling fixes (see above). iPad orientation key for App Store validation.
- Removed the profile picker from the composer; switching agents is via the chat header.

## Open items and ideas

- Uncommitted in the working tree right now: deleted `docs/images/*.png` (README still references them)
  and a leftover `HermesIOS.xcodeproj` deletion. Ask before committing or restoring.
- Upstream Hermes PRs worth sending: add `last_active` to `session.list` rows (`_session_row_summary`);
  add a `mobile` platform hint so agents use `MEDIA:` for files (then pass `source: "mobile"`).
- Not done: file cards in group chats, paths containing spaces, a "keep original image quality"
  setting, and inline image previews in chat.
- iOS 17 only has the older scroll anchor, so the Thinking-jump fix may not apply there.

## Working with the owner

Aadhil is a senior full-stack engineer (C#/.NET, Next.js, Angular, Node, Spring Boot) and newer to
Swift/iOS. He prefers a conversational tone, plans before big changes, small focused commits, and tests
for bugs he reports (UI tests for UI bugs). Explain iOS-specific reasoning briefly when it matters.
