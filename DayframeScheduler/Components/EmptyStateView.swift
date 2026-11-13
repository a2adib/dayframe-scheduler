import SwiftUI

/// Empty state: muted logo, message, and an optional action button
/// (AppFLOW 2.5: "Nothing planned. Frame your day." + Create).
struct EmptyStateView: View {
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: DayframeSpacing.lg) {
            DayframeLogoMark(size: 72)
                .opacity(0.45)
            VStack(spacing: DayframeSpacing.sm) {
                Text(title)
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.textPrimary)
                Text(message)
                    .font(DayframeFont.body)
                    .foregroundStyle(DayframeColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 220)
            }
        }
        .padding(DayframeSpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

#Preview("EmptyState") {
    EmptyStateView(
        title: "Nothing planned",
        message: "Nothing planned. Frame your day.",
        actionTitle: "Create post",
        action: {}
    )
    .background(DayframeColor.background)
}

#Preview("EmptyState dark") {
    EmptyStateView(
        title: "Nothing planned",
        message: "Nothing planned. Frame your day.",
        actionTitle: nil,
        action: nil
    )
    .background(DayframeColor.background)
    .environment(\.colorScheme, .dark)
}
