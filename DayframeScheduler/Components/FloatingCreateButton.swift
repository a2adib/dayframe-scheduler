import SwiftUI

/// Raised gradient Create button that floats over the tab bar, matching the
/// Figma Queue mock: brand-gradient circle with a white plus and a soft glow.
struct FloatingCreateButton: View {
    var size: CGFloat = 64
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(DayframeColor.brandGradient)
                .clipShape(Circle())
                .shadow(color: DayframeColor.primary.opacity(0.35), radius: size * 0.22, y: size * 0.1)
        }
        .accessibilityLabel("Create post")
    }
}

#Preview("FloatingCreateButton") {
    FloatingCreateButton(action: {})
        .padding(DayframeSpacing.xl)
        .background(DayframeColor.background)
}

#Preview("FloatingCreateButton dark") {
    FloatingCreateButton(action: {})
        .padding(DayframeSpacing.xl)
        .background(DayframeColor.background)
        .environment(\.colorScheme, .dark)
}
