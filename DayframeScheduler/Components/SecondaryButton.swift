import SwiftUI

/// Secondary action: surface-filled pill with a 1px border and dark label,
/// matching the "Channels" pill in the Figma Queue nav bar.
struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DayframeSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(DayframeFont.chip)
            .foregroundStyle(DayframeColor.textPrimary)
            .padding(.horizontal, DayframeSpacing.lg)
            .frame(minHeight: 44)
            .background(DayframeColor.surface)
            .overlay(
                Capsule().strokeBorder(DayframeColor.border, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .accessibilityLabel(title)
    }
}

#Preview("Secondary") {
    SecondaryButton(title: "Channels") {}
        .padding()
        .background(DayframeColor.background)
}

#Preview("Secondary dark") {
    SecondaryButton(title: "Channels") {}
        .padding()
        .background(DayframeColor.background)
        .environment(\.colorScheme, .dark)
}
