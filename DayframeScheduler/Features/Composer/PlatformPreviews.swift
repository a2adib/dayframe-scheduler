import SwiftUI

/// Authentic, network-tailored preview cards for each connected social network,
/// matching real mobile platform interfaces.
struct PlatformPreviewCard: View {
    var platform: Platform
    var bodyText: String
    var firstComment: String? = nil
    var media: [ComposerViewModel.PendingMedia] = []
    var handle: String = "@creator"
    var displayName: String = "Creator"
    var onOpenGridPreview: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            switch platform {
            case .instagram:
                InstagramPostPreview(
                    bodyText: bodyText,
                    firstComment: firstComment,
                    media: media,
                    handle: handle,
                    onOpenGridPreview: onOpenGridPreview
                )
            case .x:
                XPostPreview(
                    bodyText: bodyText,
                    media: media,
                    handle: handle,
                    displayName: displayName
                )
            case .linkedin:
                LinkedInPostPreview(
                    bodyText: bodyText,
                    firstComment: firstComment,
                    media: media,
                    displayName: displayName
                )
            case .facebook:
                FacebookPostPreview(
                    bodyText: bodyText,
                    media: media,
                    displayName: displayName
                )
            case .threads:
                ThreadsPostPreview(
                    bodyText: bodyText,
                    media: media,
                    handle: handle
                )
            case .tiktok, .youtube:
                TikTokPostPreview(
                    bodyText: bodyText,
                    media: media,
                    handle: handle
                )
            }
        }
    }
}

// MARK: - Instagram Preview

struct InstagramPostPreview: View {
    var bodyText: String
    var firstComment: String?
    var media: [ComposerViewModel.PendingMedia]
    var handle: String
    var onOpenGridPreview: (() -> Void)?

    var cleanHandle: String {
        handle.hasPrefix("@") ? String(handle.dropFirst()) : (handle.isEmpty ? "yourhandle" : handle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Instagram Top Header Bar
            HStack(spacing: DayframeSpacing.sm) {
                Circle()
                    .strokeBorder(DayframeColor.brandGradient, lineWidth: 2)
                    .frame(width: 38, height: 38)
                    .overlay(
                        ChannelAvatar(platform: .instagram, size: 32, showsBadge: false)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(cleanHandle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DayframeColor.textPrimary)
                    }
                    Text("Original audio")
                        .font(.system(size: 11))
                        .foregroundStyle(DayframeColor.textSecondary)
                }

                Spacer()

                if let onOpenGridPreview {
                    Button(action: onOpenGridPreview) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.3x3.fill")
                            Text("Grid View")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DayframeColor.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DayframeColor.primary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(DayframeColor.textSecondary)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, DayframeSpacing.md)
            .padding(.vertical, DayframeSpacing.sm)

            // Post Media Container (1:1 / 4:5 visual preview)
            ZStack {
                Rectangle()
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                    .aspectRatio(1.0, contentMode: .fit)

                if let firstMedia = media.first, let uiImage = UIImage(data: firstMedia.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else {
                    VStack(spacing: DayframeSpacing.sm) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text(media.isEmpty ? "Tap 'Add Media' to preview photos" : "\(media.count) items attached")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                }

                if media.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("1/\(media.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.65))
                                .clipShape(Capsule())
                                .padding(DayframeSpacing.sm)
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(Rectangle())

            // Instagram Action Row (Heart, Comment, Share, Bookmark)
            HStack(spacing: DayframeSpacing.md) {
                Image(systemName: "heart")
                    .font(.system(size: 20))
                Image(systemName: "message")
                    .font(.system(size: 19))
                Image(systemName: "paperplane")
                    .font(.system(size: 19))
                Spacer()
                Image(systemName: "bookmark")
                    .font(.system(size: 19))
            }
            .foregroundStyle(DayframeColor.textPrimary)
            .padding(.horizontal, DayframeSpacing.md)
            .padding(.top, DayframeSpacing.sm)
            .padding(.bottom, DayframeSpacing.xs)

            // Likes count
            Text("Liked by creator and others")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DayframeColor.textPrimary)
                .padding(.horizontal, DayframeSpacing.md)
                .padding(.bottom, 4)

            // Caption
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    AttributedString(cleanHandle, attributes: .init([.font: UIFont.systemFont(ofSize: 14, weight: .bold)])) +
                    AttributedString(" ") +
                    AttributedString(bodyText.isEmpty ? "Your caption will appear here..." : bodyText, attributes: .init([.font: UIFont.systemFont(ofSize: 14, weight: .regular)]))
                )
                .foregroundStyle(DayframeColor.textPrimary)
                .lineLimit(4)

                Text("View all comments")
                    .font(.system(size: 13))
                    .foregroundStyle(DayframeColor.textSecondary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, DayframeSpacing.md)

            // First Comment Box if present
            if let firstComment, !firstComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: DayframeSpacing.xs) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DayframeColor.primary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("First Comment (Automated)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DayframeColor.primary)
                            Text("• Drops right after post")
                                .font(.system(size: 10))
                                .foregroundStyle(DayframeColor.textSecondary)
                        }
                        Text(firstComment)
                            .font(.system(size: 13))
                            .foregroundStyle(DayframeColor.textPrimary)
                    }
                }
                .padding(DayframeSpacing.sm)
                .background(DayframeColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                .padding(.horizontal, DayframeSpacing.md)
                .padding(.top, DayframeSpacing.sm)
            }

            // Timestamp
            Text("JUST NOW")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DayframeColor.textSecondary)
                .padding(.horizontal, DayframeSpacing.md)
                .padding(.top, DayframeSpacing.xs)
                .padding(.bottom, DayframeSpacing.md)
        }
        .background(DayframeColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
    }
}

// MARK: - Instagram 3x3 Feed Grid Preview

struct InstagramFeedGridPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    var currentPostMedia: [ComposerViewModel.PendingMedia]
    var currentPostCaption: String
    var handle: String

    private let sampleGridColors: [Color] = [
        Color(red: 0.28, green: 0.38, blue: 0.72),
        Color(red: 0.18, green: 0.24, blue: 0.36),
        Color(red: 0.32, green: 0.58, blue: 0.52),
        Color(red: 0.72, green: 0.44, blue: 0.32),
        Color(red: 0.45, green: 0.32, blue: 0.65),
        Color(red: 0.20, green: 0.22, blue: 0.25),
        Color(red: 0.58, green: 0.52, blue: 0.32),
        Color(red: 0.32, green: 0.45, blue: 0.48),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DayframeSpacing.lg) {
                    // Header info
                    HStack(spacing: DayframeSpacing.md) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(DayframeColor.brandGradient)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Instagram Profile Grid Preview")
                                .font(DayframeFont.headline)
                                .foregroundStyle(DayframeColor.textPrimary)
                            Text("See how your new post slots into your top-left profile grid position.")
                                .font(.system(size: 13))
                                .foregroundStyle(DayframeColor.textSecondary)
                        }
                    }
                    .padding(DayframeSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DayframeColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))

                    // 3x3 Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        // Slot 0: NEW DRAFT POST
                        ZStack {
                            Rectangle()
                                .fill(Color(red: 0.15, green: 0.20, blue: 0.35))
                                .aspectRatio(1.0, contentMode: .fit)

                            if let first = currentPostMedia.first, let uiImage = UIImage(data: first.data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 22))
                                        .foregroundStyle(DayframeColor.brandGradient)
                                    Text("New Post")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }

                            // "NEW" Badge
                            VStack {
                                HStack {
                                    Text("NEW")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(DayframeColor.primary)
                                        .clipShape(Capsule())
                                        .padding(4)
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                        .overlay(
                            Rectangle()
                                .strokeBorder(DayframeColor.primary, lineWidth: 2)
                        )

                        // Slots 1 to 8: simulated past posts
                        ForEach(0..<8, id: \.self) { idx in
                            ZStack {
                                Rectangle()
                                    .fill(sampleGridColors[idx % sampleGridColors.count])
                                    .aspectRatio(1.0, contentMode: .fit)

                                VStack(spacing: 2) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white.opacity(0.4))
                                    Text("Past Post")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))

                    // Aesthetic Checklist
                    VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
                        Text("Grid Aesthetic Checklist")
                            .font(DayframeFont.headline)
                            .foregroundStyle(DayframeColor.textPrimary)

                        HStack(spacing: DayframeSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color("Success"))
                            Text("Color palette harmony with adjacent posts")
                                .font(.system(size: 13))
                        }
                        HStack(spacing: DayframeSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color("Success"))
                            Text("Clear focal subject when cropped to 1:1 square")
                                .font(.system(size: 13))
                        }
                        HStack(spacing: DayframeSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color("Success"))
                            Text("Balanced visual weight across alternating rows")
                                .font(.system(size: 13))
                        }
                    }
                    .padding(DayframeSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DayframeColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
                }
                .padding(DayframeSpacing.lg)
            }
            .background(DayframeColor.background)
            .navigationTitle("Grid Aesthetics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(DayframeFont.headline)
                        .foregroundStyle(DayframeColor.primary)
                }
            }
        }
    }
}

// MARK: - X (Twitter) Preview

struct XPostPreview: View {
    var bodyText: String
    var media: [ComposerViewModel.PendingMedia]
    var handle: String
    var displayName: String

    var cleanHandle: String {
        handle.hasPrefix("@") ? handle : "@\(handle.isEmpty ? "creator" : handle)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
            HStack(alignment: .top, spacing: DayframeSpacing.sm) {
                ChannelAvatar(platform: .x, size: 42, showsBadge: false)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(displayName.isEmpty ? "Creator" : displayName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DayframeColor.textPrimary)

                        Text(cleanHandle)
                            .font(.system(size: 14))
                            .foregroundStyle(DayframeColor.textSecondary)

                        Text("• now")
                            .font(.system(size: 13))
                            .foregroundStyle(DayframeColor.textSecondary)

                        Spacer()

                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundStyle(DayframeColor.textSecondary)
                    }

                    // Tweet Body Text
                    Text(bodyText.isEmpty ? "What's happening?" : bodyText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(DayframeColor.textPrimary)
                        .lineSpacing(2)

                    // Media preview
                    if !media.isEmpty {
                        ZStack {
                            Rectangle()
                                .fill(DayframeColor.surface)
                                .aspectRatio(16/9, contentMode: .fit)

                            if let first = media.first, let uiImage = UIImage(data: first.data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 4)
                    }

                    // X Action Row (Reply, Repost, Like, Bookmark, Share)
                    HStack {
                        actionButton(icon: "bubble.left", count: "12")
                        Spacer()
                        actionButton(icon: "arrow.2.squarepath", count: "4")
                        Spacer()
                        actionButton(icon: "heart", count: "89")
                        Spacer()
                        actionButton(icon: "chart.bar", count: "1.4k")
                        Spacer()
                        Image(systemName: "bookmark")
                            .font(.system(size: 13))
                            .foregroundStyle(DayframeColor.textSecondary)
                    }
                    .padding(.top, DayframeSpacing.xs)
                }
            }
        }
        .padding(DayframeSpacing.md)
        .background(DayframeColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
    }

    private func actionButton(icon: String, count: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
            Text(count)
                .font(.system(size: 12))
        }
        .foregroundStyle(DayframeColor.textSecondary)
    }
}

// MARK: - LinkedIn Preview

struct LinkedInPostPreview: View {
    var bodyText: String
    var firstComment: String?
    var media: [ComposerViewModel.PendingMedia]
    var displayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // LinkedIn Author Header
            HStack(alignment: .top, spacing: DayframeSpacing.sm) {
                ChannelAvatar(platform: .linkedin, size: 44, showsBadge: false)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(displayName.isEmpty ? "Creator" : displayName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DayframeColor.textPrimary)
                        Text("• 1st")
                            .font(.system(size: 12))
                            .foregroundStyle(DayframeColor.textSecondary)
                    }

                    Text("Founder & Creator • Helping creators build sustainable audiences")
                        .font(.system(size: 11))
                        .foregroundStyle(DayframeColor.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("Just now • Edited •")
                            .font(.system(size: 11))
                            .foregroundStyle(DayframeColor.textSecondary)
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DayframeColor.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(DayframeColor.textSecondary)
            }
            .padding(DayframeSpacing.md)

            // Post Text
            VStack(alignment: .leading, spacing: 4) {
                Text(bodyText.isEmpty ? "Share an update, insights, or advice..." : bodyText)
                    .font(.system(size: 14))
                    .foregroundStyle(DayframeColor.textPrimary)
                    .lineLimit(5)

                if bodyText.count > 120 {
                    Text("…see more")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DayframeColor.primary)
                }
            }
            .padding(.horizontal, DayframeSpacing.md)
            .padding(.bottom, DayframeSpacing.sm)

            // Media
            if !media.isEmpty {
                ZStack {
                    Rectangle()
                        .fill(DayframeColor.surface)
                        .aspectRatio(16/9, contentMode: .fit)

                    if let first = media.first, let uiImage = UIImage(data: first.data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    }
                }
            }

            // LinkedIn Reactions Bar
            HStack(spacing: 4) {
                HStack(spacing: -4) {
                    Circle().fill(Color.blue).frame(width: 16, height: 16)
                        .overlay(Image(systemName: "hand.thumbsup.fill").font(.system(size: 8)).foregroundStyle(.white))
                    Circle().fill(Color.green).frame(width: 16, height: 16)
                        .overlay(Image(systemName: "hands.sparkles.fill").font(.system(size: 8)).foregroundStyle(.white))
                    Circle().fill(Color.red).frame(width: 16, height: 16)
                        .overlay(Image(systemName: "heart.fill").font(.system(size: 8)).foregroundStyle(.white))
                }
                Text("42")
                    .font(.system(size: 12))
                    .foregroundStyle(DayframeColor.textSecondary)
                    .padding(.leading, 4)

                Spacer()

                Text("8 comments • 3 reposts")
                    .font(.system(size: 12))
                    .foregroundStyle(DayframeColor.textSecondary)
            }
            .padding(.horizontal, DayframeSpacing.md)
            .padding(.vertical, DayframeSpacing.xs)

            Divider()

            // LinkedIn Action Buttons
            HStack {
                linkedInAction(icon: "hand.thumbsup", label: "Like")
                Spacer()
                linkedInAction(icon: "message", label: "Comment")
                Spacer()
                linkedInAction(icon: "arrow.2.squarepath", label: "Repost")
                Spacer()
                linkedInAction(icon: "paperplane.fill", label: "Send")
            }
            .padding(.horizontal, DayframeSpacing.md)
            .padding(.vertical, DayframeSpacing.sm)

            // First comment preview
            if let firstComment, !firstComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: DayframeSpacing.xs) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DayframeColor.primary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automated First Comment")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DayframeColor.primary)
                        Text(firstComment)
                            .font(.system(size: 13))
                            .foregroundStyle(DayframeColor.textPrimary)
                    }
                }
                .padding(DayframeSpacing.sm)
                .background(DayframeColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                .padding(.horizontal, DayframeSpacing.md)
                .padding(.bottom, DayframeSpacing.md)
            }
        }
        .background(DayframeColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
    }

    private func linkedInAction(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(DayframeColor.textSecondary)
    }
}

// MARK: - Facebook Preview

struct FacebookPostPreview: View {
    var bodyText: String
    var media: [ComposerViewModel.PendingMedia]
    var displayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DayframeSpacing.sm) {
                ChannelAvatar(platform: .facebook, size: 40, showsBadge: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName.isEmpty ? "Page Name" : displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DayframeColor.textPrimary)
                    HStack(spacing: 4) {
                        Text("Just now •")
                            .font(.system(size: 11))
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(DayframeColor.textSecondary)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(DayframeColor.textSecondary)
            }
            .padding(DayframeSpacing.md)

            Text(bodyText.isEmpty ? "Write something..." : bodyText)
                .font(.system(size: 14))
                .foregroundStyle(DayframeColor.textPrimary)
                .padding(.horizontal, DayframeSpacing.md)
                .padding(.bottom, DayframeSpacing.sm)

            if !media.isEmpty {
                ZStack {
                    Rectangle()
                        .fill(DayframeColor.surface)
                        .aspectRatio(16/9, contentMode: .fit)

                    if let first = media.first, let uiImage = UIImage(data: first.data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    }
                }
            }

            Divider()
                .padding(.top, 4)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup")
                    Text("Like")
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                    Text("Comment")
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.right")
                    Text("Share")
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(DayframeColor.textSecondary)
            .padding(DayframeSpacing.md)
        }
        .background(DayframeColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
    }
}

// MARK: - Threads Preview

struct ThreadsPostPreview: View {
    var bodyText: String
    var media: [ComposerViewModel.PendingMedia]
    var handle: String

    var cleanHandle: String {
        handle.hasPrefix("@") ? String(handle.dropFirst()) : (handle.isEmpty ? "yourname" : handle)
    }

    var body: some View {
        HStack(alignment: .top, spacing: DayframeSpacing.sm) {
            VStack(spacing: 6) {
                ChannelAvatar(platform: .threads, size: 36, showsBadge: false)
                Rectangle()
                    .fill(DayframeColor.border)
                    .frame(width: 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(cleanHandle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DayframeColor.textPrimary)
                    Spacer()
                    Text("now")
                        .font(.system(size: 12))
                        .foregroundStyle(DayframeColor.textSecondary)
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundStyle(DayframeColor.textSecondary)
                }

                Text(bodyText.isEmpty ? "Start a thread..." : bodyText)
                    .font(.system(size: 14))
                    .foregroundStyle(DayframeColor.textPrimary)

                if !media.isEmpty {
                    ZStack {
                        Rectangle()
                            .fill(DayframeColor.surface)
                            .aspectRatio(4/3, contentMode: .fit)

                        if let first = media.first, let uiImage = UIImage(data: first.data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .clipped()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 4)
                }

                HStack(spacing: DayframeSpacing.lg) {
                    Image(systemName: "heart")
                    Image(systemName: "bubble.left")
                    Image(systemName: "arrow.2.squarepath")
                    Image(systemName: "paperplane")
                }
                .font(.system(size: 16))
                .foregroundStyle(DayframeColor.textPrimary)
                .padding(.top, 4)
            }
        }
        .padding(DayframeSpacing.md)
        .background(DayframeColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
    }
}

// MARK: - TikTok Preview

struct TikTokPostPreview: View {
    var bodyText: String
    var media: [ComposerViewModel.PendingMedia]
    var handle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background
            Rectangle()
                .fill(Color(red: 0.1, green: 0.1, blue: 0.12))
                .aspectRatio(9/16, contentMode: .fit)

            if let first = media.first, let uiImage = UIImage(data: first.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            }

            // Dark gradient overlay at bottom
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Right Action Rail
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: DayframeSpacing.md) {
                        tiktokIcon("heart.fill", count: "124K")
                        tiktokIcon("ellipsis.bubble.fill", count: "1.2K")
                        tiktokIcon("bookmark.fill", count: "8.5K")
                        tiktokIcon("arrowshape.turn.up.right.fill", count: "Share")
                        Circle()
                            .fill(Color.black)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            )
                    }
                    .padding(.trailing, DayframeSpacing.sm)
                    .padding(.bottom, DayframeSpacing.lg)
                }
            }

            // Bottom Caption & Creator Info
            VStack(alignment: .leading, spacing: 4) {
                Text(handle.isEmpty ? "@creator" : handle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Text(bodyText.isEmpty ? "Add your TikTok description and #hashtags..." : bodyText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)

                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                    Text("Original Audio • trending sound")
                }
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top, 2)
            }
            .padding(DayframeSpacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
    }

    private func tiktokIcon(_ systemName: String, count: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundStyle(.white)
            Text(count)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
