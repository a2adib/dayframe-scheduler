import SwiftUI

/// Placeholder tab content; replaced screen by screen in Phase 2.
struct TabPlaceholderView: View {
    let title: String
    var systemImage: String

    var body: some View {
        VStack(spacing: DayframeSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(DayframeColor.textTertiary)
            Text(title)
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DayframeColor.background)
    }
}

#Preview("Placeholder") {
    TabPlaceholderView(title: "Calendar", systemImage: "calendar")
}

#Preview("Placeholder dark") {
    TabPlaceholderView(title: "Calendar", systemImage: "calendar")
        .environment(\.colorScheme, .dark)
}
