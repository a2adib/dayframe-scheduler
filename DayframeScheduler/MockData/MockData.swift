import Foundation

enum MockData {
    static let profile = Profile(
        id: UUID(),
        displayName: "Adib Rahman",
        avatarURL: nil,
        timezone: TimeZone.current.identifier,
        theme: .system,
        plan: .free
    )

    static let channels: [Channel] = [
        Channel(
            id: UUID(), platform: .instagram, externalAccountID: "ig-1",
            handle: "@adib.builds", displayName: "Adib Builds",
            status: .connected, tokenExpiresAt: .now.addingTimeInterval(86_400 * 2)
        ),
        Channel(
            id: UUID(), platform: .x, externalAccountID: "x-1",
            handle: "@adib", displayName: "Adib",
            status: .connected, tokenExpiresAt: .now.addingTimeInterval(86_400 * 30)
        ),
        Channel(
            id: UUID(), platform: .linkedin, externalAccountID: "li-1",
            handle: "in/adibrahman", displayName: "Adib Rahman",
            status: .connected, tokenExpiresAt: .now.addingTimeInterval(86_400 * 60)
        ),
    ]

    static var channelByPlatform: [Platform: Channel] {
        Dictionary(channels.map { ($0.platform, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func posts(now: Date = .now) -> [Post] {
        let calendar = Calendar.current
        let today915 = calendar.date(bySettingHour: 9, minute: 15, second: 0, of: now) ?? now
        let today130 = calendar.date(bySettingHour: 13, minute: 30, second: 0, of: now) ?? now
        let tomorrow215 = calendar.date(byAdding: .day, value: 1, to: today915)?
            .addingTimeInterval(TimeInterval(5 * 3600)) ?? now
        let tomorrow545 = calendar.date(byAdding: .day, value: 1, to: today130)?
            .addingTimeInterval(TimeInterval(4 * 3600 + 15 * 60)) ?? now

        func targets(_ platforms: [Platform], at date: Date) -> [PostTarget] {
            platforms.compactMap { platform in
                guard let channel = channelByPlatform[platform] else { return nil }
                return PostTarget(
                    id: UUID(), channelID: channel.id, bodyOverride: nil,
                    status: .scheduled, scheduledAt: date, publishedAt: nil,
                    attempts: 0, errorMessage: nil
                )
            }
        }

        return [
            Post(
                id: UUID(),
                body: "Morning rhythm check: framing your day before opening your feeds changes everything. What's your #1 priority today?",
                status: .scheduled, scheduleMode: .queue, scheduledAt: today915, publishedAt: nil,
                targets: targets([.x, .linkedin], at: today915),
                media: []
            ),
            Post(
                id: UUID(),
                body: "Quick breakdown of our new content pipeline. Batching on Mondays gives you back 6 hours every single week. 🚀",
                status: .scheduled, scheduleMode: .custom, scheduledAt: today130, publishedAt: nil,
                targets: targets([.linkedin], at: today130),
                media: [MediaAsset(
                    id: UUID(), storagePath: "Pipeline Slides (2 images attached)", kind: .image,
                    width: 1600, height: 900, durationMS: nil, position: 0
                )]
            ),
            Post(
                id: UUID(),
                body: "Consistency is not about posting 5 times a day. It's about building a dependable cadence your community can rely on. ✨",
                status: .scheduled, scheduleMode: .queue, scheduledAt: tomorrow215, publishedAt: nil,
                targets: targets([.instagram], at: tomorrow215),
                media: []
            ),
            Post(
                id: UUID(),
                body: "Behind the scenes of the studio refresh — new lights, new backdrop, same chaos. Full tour drops Friday. 🎬",
                status: .scheduled, scheduleMode: .custom, scheduledAt: tomorrow545, publishedAt: nil,
                targets: targets([.instagram, .x], at: tomorrow545),
                media: []
            ),
        ]
    }

    static let postingSlots: [PostingSlot] = [
        PostingSlot(id: UUID(), weekday: 1, minutesFromMidnight: 9 * 60, channelID: nil, isActive: true),
        PostingSlot(id: UUID(), weekday: 1, minutesFromMidnight: 13 * 60 + 30, channelID: nil, isActive: true),
        PostingSlot(id: UUID(), weekday: 2, minutesFromMidnight: 9 * 60, channelID: nil, isActive: true),
        PostingSlot(id: UUID(), weekday: 3, minutesFromMidnight: 9 * 60, channelID: nil, isActive: true),
        PostingSlot(id: UUID(), weekday: 3, minutesFromMidnight: 17 * 60, channelID: nil, isActive: false),
        PostingSlot(id: UUID(), weekday: 4, minutesFromMidnight: 9 * 60, channelID: nil, isActive: true),
        PostingSlot(id: UUID(), weekday: 5, minutesFromMidnight: 9 * 60, channelID: nil, isActive: true),
    ]

    static let topPosts: [TopPost] = [
        TopPost(id: UUID(), body: "Batching on Mondays gives you back 6 hours every single week.", platform: .linkedin, reach: 8_420, engagement: 512),
        TopPost(id: UUID(), body: "Morning rhythm check: what's your #1 priority today?", platform: .x, reach: 5_310, engagement: 341),
        TopPost(id: UUID(), body: "Behind the scenes of the studio refresh. 🎬", platform: .instagram, reach: 4_180, engagement: 287),
    ]
}
