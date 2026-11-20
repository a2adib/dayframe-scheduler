import Foundation
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    private let profileRepository: ProfileRepository
    private let channelRepository: ChannelRepository
    private let scheduleRepository: ScheduleRepository

    private static let notificationsKey = "dayframe_notification_prefs"

    private(set) var profile: Profile?
    private(set) var channels: [Channel] = []
    private(set) var slots: [PostingSlot] = []
    private(set) var notifications: NotificationPreferences
    private(set) var isLoading = false
    var errorMessage: String?
    var showsDeleteConfirmation = false

    init(
        profileRepository: ProfileRepository,
        channelRepository: ChannelRepository,
        scheduleRepository: ScheduleRepository
    ) {
        self.profileRepository = profileRepository
        self.channelRepository = channelRepository
        self.scheduleRepository = scheduleRepository
        if let data = UserDefaults.standard.data(forKey: Self.notificationsKey),
           let saved = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            self.notifications = saved
        } else {
            self.notifications = NotificationPreferences(postPublished: true, postFailed: true, weeklyReport: false)
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        profile = try? await profileRepository.loadProfile()
        channels = (try? await channelRepository.loadChannels()) ?? []
        slots = (try? await scheduleRepository.loadSlots()) ?? []
    }

    func setTheme(_ theme: Profile.Theme) async {
        errorMessage = nil
        do {
            try await profileRepository.updateTheme(theme)
            profile?.theme = theme
        } catch {
            errorMessage = "Couldn't update theme: \(error.localizedDescription)"
        }
    }

    func toggleSlot(_ slot: PostingSlot, isActive: Bool) async {
        errorMessage = nil
        do {
            try await scheduleRepository.setSlotActive(slot, isActive: isActive)
            if let index = slots.firstIndex(where: { $0.id == slot.id }) {
                slots[index].isActive = isActive
            }
        } catch {
            errorMessage = "Couldn't update slot: \(error.localizedDescription)"
        }
    }

    func addSlot(weekday: Int, time: Date, channelID: UUID?) async {
        errorMessage = nil
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        let minutesFromMidnight = hour * 60 + minute

        do {
            let newSlot = try await scheduleRepository.addSlot(
                weekday: weekday,
                minutesFromMidnight: minutesFromMidnight,
                channelID: channelID
            )
            slots.append(newSlot)
        } catch {
            errorMessage = "Couldn't add slot: \(error.localizedDescription)"
        }
    }

    func deleteSlot(_ slot: PostingSlot) async {
        errorMessage = nil
        do {
            try await scheduleRepository.deleteSlot(slot)
            slots.removeAll { $0.id == slot.id }
        } catch {
            errorMessage = "Couldn't delete slot: \(error.localizedDescription)"
        }
    }

    func setNotification(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>, to value: Bool) {
        notifications[keyPath: keyPath] = value
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: Self.notificationsKey)
        }
    }
}
