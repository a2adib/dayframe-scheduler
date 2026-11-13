import SwiftUI

/// Character counter ring: shows remaining characters against the per-platform
/// limit (AppFLOW 2.3). Neutral below 90%, warning near the limit, danger when
/// over — icon + value so state doesn't rely on color alone.
struct CharacterCounterRing: View {
    var used: Int
    var limit: Int
    var size: CGFloat = 28

    private var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(Double(used) / Double(limit), 1)
    }

    private var isOver: Bool { used > limit }
    private var isNearLimit: Bool { !isOver && Double(used) / Double(max(limit, 1)) >= 0.9 }

    private var ringColor: Color {
        if isOver { return Color("Danger") }
        if isNearLimit { return Color("Warning") }
        return DayframeColor.primary
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DayframeColor.border, lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if isOver {
                Image(systemName: "exclamationmark")
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundStyle(Color("Danger"))
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: fraction)
        .accessibilityLabel("Used \(used) of \(limit) characters")
        .accessibilityValue(isOver ? "Over limit" : isNearLimit ? "Near limit" : "OK")
    }
}

#Preview("CounterRing") {
    HStack(spacing: DayframeSpacing.lg) {
        CharacterCounterRing(used: 40, limit: 280)
        CharacterCounterRing(used: 265, limit: 280)
        CharacterCounterRing(used: 300, limit: 280)
    }
    .padding()
    .background(DayframeColor.background)
}

#Preview("CounterRing dark") {
    HStack(spacing: DayframeSpacing.lg) {
        CharacterCounterRing(used: 40, limit: 280)
        CharacterCounterRing(used: 300, limit: 280)
    }
    .padding()
    .background(DayframeColor.background)
    .environment(\.colorScheme, .dark)
}
