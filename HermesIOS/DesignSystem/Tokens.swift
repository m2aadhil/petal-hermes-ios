import SwiftUI
import UIKit

/// Hermès iOS design tokens.
///
/// Every colour, spacing step, radius, size and animation used by the app is
/// defined here. Views should reference these tokens instead of literals so
/// the visual language stays consistent and can evolve in one place.
/// See docs/DESIGN_SYSTEM.md.
enum DS {

    // MARK: - Colour

    /// Semantic colours. Each adapts to light and dark appearance.
    enum Palette {
        /// Warm paper background behind every screen.
        static let background = dynamic(light: 0xF8F6F1, dark: 0x131414)
        /// Raised surfaces: cards, rows, the composer, round buttons.
        static let surface = dynamic(light: 0xFFFFFF, dark: 0x212121)
        /// Recessed areas inside a surface, e.g. text fields and chips in a card.
        static let sunken = background
        /// Hairline borders and dividers.
        static let line = Color.primary.opacity(0.08)
        /// Slightly stronger border for focused or selected elements.
        static let lineStrong = Color.primary.opacity(0.14)

        /// Brand terracotta. Use for fills, icons and the primary action.
        /// White text on it meets WCAG AA in both appearances.
        static let accent = Color(hex: 0xCF4A30)
        /// Accent for text and small glyphs on `background`/`surface` (≥ 4.5:1).
        static let accentText = dynamic(light: 0xB23E27, dark: 0xE2674B)
        /// Tinted wash behind accent icons and selected rows.
        static let accentSoft = accent.opacity(0.08)
        /// Foreground on top of `accent`.
        static let onAccent = Color.white

        static let success = dynamic(light: 0x3C7A55, dark: 0x62B283)
        static let warning = dynamic(light: 0xB7791A, dark: 0xE6A53C)
        /// Errors and destructive states. Always pair with an icon; never rely on colour alone.
        static let critical = dynamic(light: 0xB42318, dark: 0xFF7A6E)

        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color(uiColor: .tertiaryLabel)
        static let disabledFill = Color.secondary.opacity(0.28)

        /// Stable per-agent tint, derived from the profile name.
        static let agentTints: [Color] = [accent, Color(hex: 0x4D6E59), Color(hex: 0x706496), Color(hex: 0x617A9E)]
        static func agentTint(_ name: String) -> Color {
            agentTints[name.utf8.reduce(0) { ($0 + Int($1)) % agentTints.count }]
        }

        private static func dynamic(light: UInt32, dark: UInt32) -> Color {
            Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
        }
    }

    // MARK: - Spacing (4-pt scale)

    enum Space {
        static let hairline: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 28
        static let xxxl: CGFloat = 40
        /// Horizontal margin for full-screen content.
        static let screen: CGFloat = 24
    }

    // MARK: - Corner radius

    enum Radius {
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 28
        static let sheet: CGFloat = 30
    }

    // MARK: - Sizes

    enum Size {
        /// Minimum hit target (HIG).
        static let tap: CGFloat = 44
        /// Text fields, search fields and secondary controls.
        static let control: CGFloat = 48
        /// Primary, full-width buttons.
        static let button: CGFloat = 56
        static let iconTile: CGFloat = 40
        static let voiceSecondary: CGFloat = 58
        static let voicePrimary: CGFloat = 76
        static let dot: CGFloat = 6

        /// Readable column widths on iPad / landscape.
        static let formWidth: CGFloat = 540
        static let contentWidth: CGFloat = 680
        static let chatWidth: CGFloat = 720
    }

    // MARK: - Motion

    enum Motion {
        static var quick: Animation { .easeOut(duration: 0.18) }
        static var standard: Animation { .spring(response: 0.35, dampingFraction: 0.86) }
        /// Returns nil when Reduce Motion is on, so callers can pass it straight to `withAnimation`.
        static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation? { reduceMotion ? nil : animation }
    }

    // MARK: - Elevation

    enum Elevation {
        case flat, floating
        var color: Color { self == .floating ? .black.opacity(0.05) : .clear }
        var radius: CGFloat { self == .floating ? 22 : 0 }
        var y: CGFloat { self == .floating ? 6 : 0 }
    }
}

extension View {
    func elevation(_ level: DS.Elevation) -> some View {
        shadow(color: level.color, radius: level.radius, y: level.y)
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
