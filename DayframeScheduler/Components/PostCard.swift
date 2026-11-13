import SwiftUI

/// Queue post card: white rounded card with a 1px border — overlapping channel
/// avatars + time on the leading side, status chip trailing, body text, and an
/// optional media attachment. Measured from the Figma Queue mock (node 4-3).
struct PostCard: View {
    var platforms: [Platform]
    var timeText: String
    var status: PostStatus
    var bodyText: String
    var mediaCaption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            HStack(spacing: DayframeSpacing.sm) {
                overlappingAvatars
                Text(timeText)
                    .font(DayframeFont.chip)
                    .foregroundStyle(DayframeColor.textSecondary)
                Spacer()
                StatusChip(status: status, size: .compact)
            }

            Text(bodyText)
                .font(DayframeFont.body)
                .foregroundStyle(DayframeColor.textPrimary)

            if let mediaCaption {
                mediaAttachment(caption: mediaCaption)
            }
        }
        .padding(DayframeSpacing.lg)
        .background(DayframeColor.background)
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var overlappingAvatars: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(platforms.prefix(3).enumerated()), id: \.offset) { _, platform in
                ChannelAvatar(platform: platform, size: size, showsBadge: false)
                    .overlay(alignment: .bottomTrailing) {
                        PlatformBadge(platform: platform, size: size * 0.42)
                            .offset(x: size * 0.08, y: size * 0.08)
                    }
                    .zIndex(platform == platforms.first ? 1 : 0)
            }
        }
    }

    private var size: CGFloat { 36 }

    private func mediaAttachment(caption: String) -> some View {
        HStack(spacing: DayframeSpacing.sm) {
            Image(systemName: "photo.on.rectangle.angled")
            Text(caption)
                .font(DayframeFont.chip)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .background(DayframeColor.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
    }
}

#Preview("PostCard") {
    VStack(spacing: DayframeSpacing.lg) {
        PostCard(
            platforms: [.x, .linkedin],
            timeText: "9:15 AM",
            status: .scheduled,
            bodyText: "Morning rhythm check: framing your day before opening your feeds changes everything. What's your #1 priority today?",
            mediaCaption: nil
        )
        PostCard(
            platforms: [.linkedin],
            timeText: "1:30 PM",
            status: .scheduled,
            bodyText: "Quick breakdown of our new content pipeline. Batching on Mondays gives you back 6 hours every single week. 🚀",
            mediaCaption: "Pipeline Slides (2 images attached)"
        )
    }
    .padding()
    .background(DayframeColor.background)
}

#Preview("PostCard dark") {
    PostCard(
        platforms: [.instagram],
        timeText: "2:15 PM",
        status: .failed,
        bodyText: "Consistency is not about posting 5 times a day. It's about building a dependable cadence your community can rely on. ✨",
        mediaCaption: nil
    )
    .padding()
    .background(DayframeColor.background)
    .environment(\.colorScheme, .dark)
}
