import SwiftUI

/// Post status chip: tinted pill with icon + text so status never relies on
/// color alone (UI_Spec §7). Scheduled styling measured from the Figma Queue
/// mock (#E5E9FF background, #2C4BFF text).
enum PostStatus: String, Codable {
    case draft
    case scheduled
    case publishing
    case published
    case failed

    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .scheduled: "Scheduled"
        case .publishing: "Publishing"
        case .published: "Published"
        case .failed: "Failed"
        }
    }

    var systemImage: String {
        switch self {
        case .draft: "pencil"
        case .scheduled: "clock"
        case .publishing: "arrow.up.circle"
        case .published: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}

struct StatusChip: View {
    var status: PostStatus
    var size: StatusChipSize = .regular

    enum StatusChipSize {
        case regular, compact

        var font: Font { self == .regular ? DayframeFont.chip : .system(size: 12, weight: .semibold) }
        var verticalPadding: CGFloat { self == .regular ? DayframeSpacing.xs + 2 : DayframeSpacing.xs }
        var horizontalPadding: CGFloat { self == .regular ? DayframeSpacing.md : DayframeSpacing.sm + 2 }
    }

    var body: some View {
        HStack(spacing: DayframeSpacing.xs) {
            Image(systemName: status.systemImage)
            Text(status.displayName)
        }
        .font(size.font)
        .foregroundStyle(textColor)
        .padding(.vertical, size.verticalPadding)
        .padding(.horizontal, size.horizontalPadding)
        .background(backgroundColor)
        .clipShape(Capsule())
        .accessibilityLabel("Status: \(status.displayName)")
    }

    private var backgroundColor: Color {
        switch status {
        case .scheduled, .publishing: DayframeColor.statusScheduledBackground
        case .published: Color("Success").opacity(0.15)
        case .failed: Color("Danger").opacity(0.15)
        case .draft: DayframeColor.surface
        }
    }

    private var textColor: Color {
        switch status {
        case .scheduled, .publishing: DayframeColor.statusScheduledText
        case .published: Color("Success")
        case .failed: Color("Danger")
        case .draft: DayframeColor.textSecondary
        }
    }
}

#Preview("Statuses") {
    VStack(spacing: DayframeSpacing.md) {
        ForEach([PostStatus.draft, .scheduled, .publishing, .published, .failed], id: \.self) { status in
            StatusChip(status: status)
        }
        StatusChip(status: .scheduled, size: .compact)
    }
    .padding()
    .background(DayframeColor.background)
}

#Preview("Statuses dark") {
    VStack(spacing: DayframeSpacing.md) {
        ForEach([PostStatus.draft, .scheduled, .published, .failed], id: \.self) { status in
            StatusChip(status: status)
        }
    }
    .padding()
    .background(DayframeColor.background)
    .environment(\.colorScheme, .dark)
}
