import SwiftUI

/// The six-petal Hermes mark.
struct AgentMark: View {
    var size: CGFloat = 52
    var color: Color = DS.Palette.accent
    var body: some View {
        ZStack {
            ForEach(0..<6) { index in
                Ellipse().fill(color)
                    .frame(width: size * 0.22, height: size * 0.52)
                    .offset(y: -size * 0.21)
                    .rotationEffect(.degrees(Double(index) * 60))
            }
            Circle().fill(DS.Palette.background).frame(width: size * 0.14)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Rounded-square avatar tinted per agent.
struct AgentAvatar: View {
    let name: String
    var size: CGFloat = 48
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous).fill(DS.Palette.agentTint(name).opacity(0.12))
            if name == "default" { AgentMark(size: size * 0.54) }
            else {
                Image(systemName: name == "research" ? "sparkle.magnifyingglass" : name == "studio" ? "pencil.and.outline" : "sparkle")
                    .font(.system(size: size * 0.42, weight: .medium)).foregroundStyle(DS.Palette.agentTint(name))
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// Mark + "Hermès iOS" logotype.
struct Wordmark: View {
    var markSize: CGFloat = 28
    var body: some View {
        HStack(spacing: DS.Space.xs + 2) {
            AgentMark(size: markSize)
            Text(verbatim: "Hermès iOS").textStyle(.wordmark)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
