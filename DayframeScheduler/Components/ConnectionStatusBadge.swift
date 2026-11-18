import SwiftUI

/// Connection status badge: tinted pill showing channel connection health
/// (Connected, Needs Reauth, Paused).
struct ConnectionStatusBadge: View {
    var health: ConnectionHealth
    var compact: Bool = false

    var body: some View {
        HStack(spacing: DayframeSpacing.xs) {
            Image(systemName: health.systemImage)
            Text(health.rawValue)
        }
        .font(compact ? .system(size: 11, weight: .semibold) : DayframeFont.chip)
        .foregroundStyle(textColor)
        .padding(.vertical, compact ? 3 : DayframeSpacing.xs)
        .padding(.horizontal, compact ? DayframeSpacing.sm : DayframeSpacing.md)
        .background(backgroundColor)
        .clipShape(Capsule())
        .accessibilityLabel("Connection: \(health.rawValue)")
    }

    private var backgroundColor: Color {
        switch health {
        case .connected:
            return Color("Success").opacity(0.15)
        case .needsReauth:
            return Color("Warning").opacity(0.18)
        case .paused:
            return Color.orange.opacity(0.15)
        }
    }

    private var textColor: Color {
        switch health {
        case .connected:
            return Color("Success")
        case .needsReauth:
            return Color("Warning")
        case .paused:
            return Color.orange
        }
    }
}

#Preview("ConnectionBadges") {
    VStack(spacing: DayframeSpacing.md) {
        ConnectionStatusBadge(health: .connected)
        ConnectionStatusBadge(health: .needsReauth)
        ConnectionStatusBadge(health: .paused)
        ConnectionStatusBadge(health: .paused, compact: true)
    }
    .padding()
    .background(DayframeColor.background)
}
