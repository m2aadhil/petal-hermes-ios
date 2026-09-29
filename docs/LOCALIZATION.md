# Localization

Hermès iOS uses Xcode **String Catalogs**. English is the development (source) language; French is the first translation.

| File | Contents |
| --- | --- |
| `HermesIOS/Resources/Localizable.xcstrings` | All UI strings, errors, notices and demo content |
| `HermesIOS/Resources/InfoPlist.xcstrings` | Permission prompts (`NSMicrophoneUsageDescription`, `NSLocalNetworkUsageDescription`) and display name |

`SWIFT_EMIT_LOC_STRINGS = YES` is on, so Xcode adds new keys to the catalog on every build and marks keys that are no longer used as *stale*.

## Writing localizable code

- Literals passed to SwiftUI (`Text("…")`, `Button("…")`, `Label("…", systemImage:)`, `.navigationTitle("…")`, `.accessibilityLabel("…")`) are localized automatically.
- A **`String` variable** passed to `Text` is *not* localized. Any string built outside a view, such as a model notice, a thrown `RPCFailure`, a computed `title`, or a prompt inserted into the draft, must use `String(localized: "…")`.
- Reusable components take `LocalizedStringKey`, not `String`, for their labels (`PrimaryButton`, `RoundButton`, `field`, `suggestion`, `instruction`).
- Use `Text(verbatim:)` for text that must never be translated: brand names, commands, env vars and numbers.
- If a ternary mixes a literal with a runtime `String`, wrap the literal: `cond ? String(localized: "No instructions available.") : content`.
- Counts use plural variations in the catalog (`%lld conversations`, `%lld tasks`, `%lld agents`).
- Add a `comment:` when the context isn't obvious (for example `"Kanban status"` or `"Demo data"`).

## Adding a language

1. Open `Localizable.xcstrings` in Xcode, click **+** and pick the language. Do the same for `InfoPlist.xcstrings`.
2. Translate every entry, including plural variations. Placeholders (`%@`, `%lld`) must be kept; reorder with `%1$@` / `%2$@` if needed.
3. Run the app with *Edit Scheme → Run → Options → App Language* set to the new language, and check the onboarding, chat, tools drawer and settings screens for truncation.
4. `xcodegen generate` keeps the catalogs because they live under `HermesIOS/`. Also check that `knownRegions` in the project includes the new language code.

Users switch language in **iOS Settings → Hermès iOS → Language**. The in-app *Settings → Preferences → Language* row links there.

UI tests pin `-AppleLanguages (en)` so label-based queries stay deterministic.
