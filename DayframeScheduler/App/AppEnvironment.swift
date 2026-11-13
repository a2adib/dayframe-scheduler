import Foundation
import Observation

/// Dependency container injected through the environment (TRD.md §2).
@Observable
final class AppEnvironment {
    let profileRepository: ProfileRepository
    let channelRepository: ChannelRepository
    let postRepository: PostRepository
    let analyticsRepository: AnalyticsRepository
    let scheduleRepository: ScheduleRepository

    init(
        profileRepository: ProfileRepository = MockProfileRepository(),
        channelRepository: ChannelRepository = MockChannelRepository(),
        postRepository: PostRepository = MockPostRepository(),
        analyticsRepository: AnalyticsRepository = MockAnalyticsRepository(),
        scheduleRepository: ScheduleRepository = MockScheduleRepository()
    ) {
        self.profileRepository = profileRepository
        self.channelRepository = channelRepository
        self.postRepository = postRepository
        self.analyticsRepository = analyticsRepository
        self.scheduleRepository = scheduleRepository
    }
}

extension AppEnvironment {
    static let shared = AppEnvironment()
}
