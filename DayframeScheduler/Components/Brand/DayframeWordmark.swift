import SwiftUI

/// The Dayframe wordmark: "Day" in text-primary, "frame" in primary blue,
/// bold rounded type. Colors measured from the Figma `dayframe-logo-lockup`
/// frame (node 1-2).
struct DayframeWordmark: View {
    var size: CGFloat = 32

    var body: some View {
        Text("Day")
            .font(DayframeFont.title(size))
            .foregroundColor(DayframeColor.textPrimary)
        + Text("frame")
            .font(DayframeFont.title(size))
            .foregroundColor(DayframeColor.primary)
            .accessibilityLabel("Dayframe")
    }
}

#Preview("Wordmark") {
    DayframeWordmark()
        .padding()
        .background(DayframeColor.background)
}

#Preview("Wordmark dark") {
    DayframeWordmark()
        .padding()
        .background(DayframeColor.background)
        .environment(\.colorScheme, .dark)
}
