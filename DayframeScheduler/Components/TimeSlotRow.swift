import SwiftUI

/// Posting-schedule slot row: day selector with time slots, used by the
/// schedule editor (AppFLOW 2.8). Toggle row with time text.
struct TimeSlotRow: View {
    let title: String
    var subtitle: String?
    @Binding var isActive: Bool
    var onToggle: () -> Void = {}

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                Text(title)
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(DayframeColor.textSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isActive)
                .labelsHidden()
                .tint(DayframeColor.primary)
                .onChange(of: isActive) { _, _ in onToggle() }
        }
        .padding(.vertical, DayframeSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

#Preview("TimeSlotRow") {
    List {
        TimeSlotRow(title: "9:00 AM", subtitle: "All channels", isActive: .constant(true))
        TimeSlotRow(title: "1:30 PM", subtitle: "Instagram", isActive: .constant(false))
    }
}

#Preview("TimeSlotRow dark") {
    List {
        TimeSlotRow(title: "6:00 PM", subtitle: "LinkedIn, X", isActive: .constant(true))
    }
    .environment(\.colorScheme, .dark)
}
