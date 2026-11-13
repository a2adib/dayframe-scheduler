import SwiftUI

/// Queue section header: bold title with a trailing count pill, matching the
/// "Today — 3 posts" rows in the Figma Queue mock.
struct SectionHeader: View {
    let title: String
    var trailingText: String?

    var body: some View {
        HStack {
            Text(title)
                .font(DayframeFont.sectionHeader)
                .foregroundStyle(DayframeColor.textPrimary)
            Spacer()
            if let trailingText {
                Text(trailingText)
                    .font(DayframeFont.chip)
                    .foregroundStyle(DayframeColor.textSecondary)
                    .padding(.vertical, DayframeSpacing.xs + 2)
                    .padding(.horizontal, DayframeSpacing.md)
                    .background(DayframeColor.surface)
                    .overlay(Capsule().strokeBorder(DayframeColor.border, lineWidth: 1))
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("SectionHeader") {
    SectionHeader(title: "Today", trailingText: "3 posts")
        .padding()
        .background(DayframeColor.background)
}

#Preview("SectionHeader dark") {
    SectionHeader(title: "Tomorrow", trailingText: "2 posts")
        .padding()
        .background(DayframeColor.background)
        .environment(\.colorScheme, .dark)
}
