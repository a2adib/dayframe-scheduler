import SwiftUI

/// Channel avatar: a circle (account image or placeholder person glyph) with a
/// small platform badge at the lower right, matching the Figma Queue mock.
struct ChannelAvatar: View {
    var platform: Platform
    var size: CGFloat = 36
    var showsBadge: Bool = true

    var body: some View {
        Circle()
            .fill(DayframeColor.surface)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(Color(red: 0.39, green: 0.54, blue: 0.67))
            )
            .overlay(alignment: .bottomTrailing) {
                if showsBadge {
                    PlatformBadge(platform: platform, size: size * 0.42)
                        .offset(x: size * 0.06, y: size * 0.06)
                }
            }
            .frame(width: size, height: size)
            .accessibilityLabel("Channel on \(platform.displayName)")
    }
}

/// Small circular platform badge. Drawn with system-style glyphs, mirroring
/// the badges in the Figma Queue mock (X, LinkedIn, Instagram).
struct PlatformBadge: View {
    var platform: Platform
    var size: CGFloat = 15

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundStyle)
                .overlay(Circle().strokeBorder(.white, lineWidth: max(1, size * 0.07)))
            glyph
                .font(.system(size: size * 0.62, weight: .bold))
                .foregroundStyle(foregroundColor)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var backgroundStyle: AnyShapeStyle {
        switch platform {
        case .instagram: AnyShapeStyle(DayframeColor.brandGradient)
        case .x: AnyShapeStyle(.black)
        case .linkedin: AnyShapeStyle(Color(red: 0.04, green: 0.40, blue: 0.76))
        case .facebook: AnyShapeStyle(Color(red: 0.09, green: 0.45, blue: 0.93))
        case .tiktok: AnyShapeStyle(.black)
        case .youtube: AnyShapeStyle(.red)
        }
    }

    private var foregroundColor: Color {
        platform == .tiktok ? Color(red: 0.16, green: 0.83, blue: 0.96) : .white
    }

    @ViewBuilder
    private var glyph: some View {
        switch platform {
        case .x: Text("𝕏")
        case .linkedin: Text("in")
        case .facebook: Text("f")
        case .youtube: Image(systemName: "play.fill")
        case .tiktok: Image(systemName: "music.note")
        case .instagram: Image(systemName: "camera.fill")
        }
    }
}

extension Platform {
    var displayName: String {
        switch self {
        case .instagram: "Instagram"
        case .x: "X (Twitter)"
        case .linkedin: "LinkedIn"
        case .facebook: "Facebook"
        case .tiktok: "TikTok"
        case .youtube: "YouTube"
        }
    }
}

#Preview("Avatars") {
    HStack(spacing: DayframeSpacing.lg) {
        ForEach(Platform.allCases, id: \.self) { platform in
            ChannelAvatar(platform: platform, size: 44)
        }
    }
    .padding()
    .background(DayframeColor.background)
}

#Preview("Avatars dark") {
    HStack(spacing: DayframeSpacing.lg) {
        ForEach(Platform.allCases, id: \.self) { platform in
            ChannelAvatar(platform: platform, size: 44)
        }
    }
    .padding()
    .background(DayframeColor.background)
    .environment(\.colorScheme, .dark)
}
