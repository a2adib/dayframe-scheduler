import SwiftUI

/// Primary call-to-action: brand-gradient pill with white bold label
/// (matches the gradient action surfaces in the Figma Queue mock).
struct PrimaryButton: View {
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
            .font(DayframeFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(DayframeColor.brandGradient)
            .clipShape(Capsule())
        }
        .accessibilityLabel(title)
    }
}

#Preview("Primary") {
    VStack(spacing: DayframeSpacing.lg) {
        PrimaryButton(title: "Schedule") {}
        PrimaryButton(title: "Post now", systemImage: "paperplane.fill") {}
    }
    .padding()
    .background(DayframeColor.background)
}

#Preview("Primary dark") {
    PrimaryButton(title: "Schedule") {}
        .padding()
        .background(DayframeColor.background)
        .environment(\.colorScheme, .dark)
}
