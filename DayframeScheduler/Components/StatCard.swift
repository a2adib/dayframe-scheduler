import SwiftUI

/// Analytics stat card: value, label, and trend arrow with delta
/// (UI_Spec §4.7). No Figma frame exists; styling follows the card token set.
struct StatCard: View {
    let value: String
    let label: String
    var trend: Trend = .none
    var trendDelta: String?

    enum Trend {
        case up, down, none

        var systemImage: String {
            switch self {
            case .up: "arrow.up.right"
            case .down: "arrow.down.right"
            case .none: ""
            }
        }

        var color: Color { self == .down ? Color("Danger") : Color("Success") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DayframeColor.textSecondary)
                Spacer()
                if trend != .none {
                    HStack(spacing: 2) {
                        Image(systemName: trend.systemImage)
                        if let trendDelta {
                            Text(trendDelta)
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(trend.color)
                }
            }
            Text(value)
                .font(DayframeFont.largeTitle(24))
                .foregroundStyle(DayframeColor.textPrimary)
        }
        .padding(DayframeSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DayframeColor.background)
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview("StatCard") {
    HStack(spacing: DayframeSpacing.md) {
        StatCard(value: "12.4k", label: "Reach", trend: .up, trendDelta: "+8%")
        StatCard(value: "3.2%", label: "Engagement", trend: .down, trendDelta: "-1%")
    }
    .padding()
    .background(DayframeColor.surface)
}

#Preview("StatCard dark") {
    HStack(spacing: DayframeSpacing.md) {
        StatCard(value: "486", label: "Followers", trend: .up, trendDelta: "+12")
        StatCard(value: "1.9k", label: "Clicks", trend: .none)
    }
    .padding()
    .background(DayframeColor.surface)
    .environment(\.colorScheme, .dark)
}
