# Design system

Hermès iOS aims to be calm, warm and native: paper-toned backgrounds, one terracotta accent, serif headlines and SF body text. The design system turns that look into tokens and components so every screen stays consistent and works with Dynamic Type, dark mode and VoiceOver.

Code lives in `HermesIOS/DesignSystem/`:

| File | What's in it |
| --- | --- |
| `Tokens.swift` | `DS.Palette`, `DS.Space`, `DS.Radius`, `DS.Size`, `DS.Motion`, `DS.Elevation` |
| `Typography.swift` | `TextStyle` + `.textStyle(_:)`, `IconSize` + `.icon(_:)`. Both scale with Dynamic Type |
| `Components.swift` | Buttons, surfaces, fields, headers, feedback, layout helpers |
| `Brand.swift` | `AgentMark`, `AgentAvatar`, `Wordmark` |
| `Gallery.swift` | `DesignSystemGallery`, a DEBUG preview in light, dark and accessibility sizes |

Open `Gallery.swift` in Xcode's canvas whenever you change a token.

## Rules

1. **Don't use literals in views.** Use `DS.Space`, `DS.Radius` and `DS.Size` for layout, `DS.Palette` for colour, and `.textStyle` / `.icon` for fonts. Avoid `.font(.system(size:))` because it stops Dynamic Type from working.
2. **Accent is for action and identity, not errors.** Use `DS.Palette.accent` for fills and icons, `accentText` for accent-coloured text, and `critical` (always with an icon) for errors. `InlineMessage` handles errors for you.
3. **Use the shared components** instead of rebuilding them: `PrimaryButton`, `HermesButtonStyle`, `IconButton`, `SearchField`, `FormField`, `ScreenHeader`, `SectionLabel`, `InlineMessage`, `IconTile`, `StatusDot`, `.card()`, `.tile(selected:)`, `.rowHighlight(_:)`, `.fieldStyle()`, `.readableWidth()`.
4. **Keep hit targets at least 44 pt** (`DS.Size.tap`). Icon-only buttons need an accessibility label, which `IconButton` requires.
5. **Respect Reduce Motion.** Wrap animations with `DS.Motion.adaptive(_:reduceMotion:)`. The button styles already do this.

## Tokens at a glance

**Colour.** Every colour adapts to light and dark mode.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `background` | `#F8F6F1` | `#131414` | Screen background |
| `surface` | `#FFFFFF` | `#212121` | Cards, rows, composer, round buttons |
| `sunken` | = background | = background | Fields inside cards |
| `accent` | `#CF4A30` | `#CF4A30` | Primary fills and icons (white on it passes AA) |
| `accentText` | `#B23E27` | `#E2674B` | Accent-coloured text (at least 4.5:1) |
| `success` / `warning` / `critical` | `#3C7A55` / `#B7791A` / `#B42318` | `#62B283` / `#E6A53C` / `#FF7A6E` | Status |

**Spacing** follows a 4 pt scale: `xxs 4 · xs 8 · s 12 · m 16 · l 20 · xl 24 · xxl 28 · xxxl 40`, with `screen = 24` for page margins.

**Radius:** `xs 8 · s 12 · m 16 · l 20 · xl 24 · xxl 28 · sheet 30`. All radii use continuous corners.

**Type:**

| Style | Spec | Use |
| --- | --- | --- |
| `hero` | serif 40 | Onboarding and empty-chat headline |
| `display` | serif 32 | Screen titles |
| `title` | serif 26 | Sheet titles |
| `wordmark` | rounded semibold 26 | "Hermès iOS" logotype |
| `overline` | 11 semibold uppercase | Eyebrow text |
| Everything else | SF system text styles | `headline`, `body`, `label`, `caption`, … |

The serif sizes scale relative to `.largeTitle` / `.title` via `@ScaledMetric`.

## Adding a component

Put it in `Components.swift` if it appears on two or more screens. Build it only from tokens, add it to the gallery, and use `Text(verbatim:)` or existing catalog keys in the gallery so it doesn't add untranslated strings (see [localization](LOCALIZATION.md)).
