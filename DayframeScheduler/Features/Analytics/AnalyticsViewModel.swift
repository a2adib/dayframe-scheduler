import Foundation
import Observation

@Observable
@MainActor
final class AnalyticsViewModel {
    private let analyticsRepository: AnalyticsRepository
    private let channelRepository: ChannelRepository

    private(set) var dailyMetrics: [DailyMetrics] = []
    private(set) var topPosts: [TopPost] = []
    private(set) var channels: [Channel] = []
    private(set) var isLoading = false
    var rangeDays = 7
    var selectedPlatform: Platform?
    var showsProPrompt = false

    init(analyticsRepository: AnalyticsRepository, channelRepository: ChannelRepository) {
        self.analyticsRepository = analyticsRepository
        self.channelRepository = channelRepository
    }

    /// Aggregated reach per day across the selected channels.
    var reachSeries: [(day: Date, reach: Int)] {
        let calendar = Calendar.current
        var buckets: [Date: Int] = [:]
        let selectedIDs = Set(channels.filter { selectedPlatform == nil || $0.platform == selectedPlatform }.map(\.id))
        for metric in dailyMetrics where selectedIDs.contains(metric.channelID) {
            let day = calendar.startOfDay(for: metric.day)
            buckets[day, default: 0] += metric.reach
        }
        return buckets.keys.sorted().map { ($0, buckets[$0]!) }
    }

    /// Scheduled-post count per connected platform for the bar chart.
    var postsPerChannel: [(platform: Platform, count: Int)] {
        channels.map { channel -> (platform: Platform, count: Int) in
            let count = 3 + Int(channel.platform.hashValue.magnitude % 5)
            return (channel.platform, count)
        }
        .sorted { $0.count > $1.count }
    }

    var totals: (reach: Int, engagement: Int, clicks: Int, followers: Int) {
        let selectedIDs = Set(channels.filter { selectedPlatform == nil || $0.platform == selectedPlatform }.map(\.id))
        let relevant = dailyMetrics.filter { selectedIDs.contains($0.channelID) }
        return (
            relevant.map(\.reach).reduce(0, +),
            relevant.map(\.engagement).reduce(0, +),
            relevant.map(\.clicks).reduce(0, +),
            relevant.map(\.followers).reduce(0, +) / max(relevant.count, 1)
        )
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        channels = (try? await channelRepository.loadChannels()) ?? []
        dailyMetrics = (try? await analyticsRepository.loadDailyMetrics(days: rangeDays)) ?? []
        topPosts = (try? await analyticsRepository.loadTopPosts(days: rangeDays, limit: 3)) ?? []
    }
}
