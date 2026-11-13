import SwiftUI

/// The Dayframe logo mark: a rounded-square ring in the brand gradient with an
/// amber sun dot at the upper right. Geometry measured from the Figma
/// `dayframe-mark` frame (node 2-2, 200×200): outer ring inset 15.5, stroke 25,
/// outer corner radius 50, dot center (120.5, 80.5) r 21.5.
struct DayframeLogoMark: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.1875, style: .continuous)
                .stroke(
                    DayframeColor.brandGradient,
                    lineWidth: size * 0.125
                )
                .padding(size * 0.14)
            Circle()
                .fill(DayframeColor.logoAmber)
                .frame(width: size * 0.215, height: size * 0.215)
                .offset(x: size * 0.1025, y: -size * 0.0975)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Dayframe logo")
    }
}

#Preview("Mark") {
    DayframeLogoMark()
        .padding()
        .background(DayframeColor.background)
}

#Preview("Mark sizes") {
    HStack(alignment: .center, spacing: DayframeSpacing.lg) {
        ForEach([24, 29, 48, 96, 120], id: \.self) { s in
            DayframeLogoMark(size: CGFloat(s))
        }
    }
    .padding()
    .background(DayframeColor.background)
}

#Preview("Mark dark") {
    DayframeLogoMark()
        .padding()
        .background(DayframeColor.background)
        .environment(\.colorScheme, .dark)
}
