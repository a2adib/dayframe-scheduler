import SwiftUI

/// Launch placeholder (Phase 0): centered Dayframe lockup on the background
/// token. Replaced by the onboarding/auth flow in Phase 2.
struct LaunchView: View {
    var body: some View {
        VStack(spacing: DayframeSpacing.lg) {
            DayframeLogoMark(size: 96)
            DayframeWordmark(size: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DayframeColor.background)
    }
}

#Preview("Launch light") {
    LaunchView()
}

#Preview("Launch dark") {
    LaunchView()
        .environment(\.colorScheme, .dark)
}
