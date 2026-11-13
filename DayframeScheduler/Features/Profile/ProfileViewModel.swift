import Foundation
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    private let profileRepository: ProfileRepository
    private let channelRepository: ChannelRepository
    private let scheduleRepository: ScheduleRepository

    private(set) var profile: Profile?
    private(set) var channels: [Channel] = []
    private(set) var slots: [PostingSlot] = []
    private(set) var notifications = NotificationPreferences(postPublished: true, postFailed: true, weeklyReport: false)
    private(set) var isLoading = false
    var showsDeleteConfirmation = false

    init(
        profileRepository: ProfileRepository,
        channelRepository: ChannelRepository,
        scheduleRepository: ScheduleRepository
    ) {
        self.profileRepository = profileRepository
        self.channelRepository = channelRepository
        self.scheduleRepository = scheduleRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        profile = try? await profileRepository.loadProfile()
        channels = (try? await channelRepository.loadChannels()) ?? []
        slots = (try? await scheduleRepository.loadSlots()) ?? []
    }

    func setTheme(_ theme: Profile.Theme) async {
        try? await profileRepository.updateTheme(theme)
        profile?.theme = theme
    }

    func toggleSlot(_ slot: PostingSlot, isActive: Bool) async {
        try? await scheduleRepository.setSlotActive(slot, isActive: isActive)
        if let index = slots.firstIndex(where: { $0.id == slot.id }) {
            slots[index].isActive = isActive
        }
    }

    func setNotification(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>, to value: Bool) {
        notifications[keyPath: keyPath] = value
    }

    func logout() async {
        try? await profileRepository.logout()
    }
}
