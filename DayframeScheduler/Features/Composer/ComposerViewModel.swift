import Foundation
import Observation
import PhotosUI
import SwiftUI

@Observable
@MainActor
final class ComposerViewModel {
    struct PendingMedia: Identifiable, Equatable {
        let id = UUID()
        let data: Data
    }

    private let channelRepository: ChannelRepository
    private let postRepository: PostRepository
    private let scheduleRepository: ScheduleRepository

    private(set) var channels: [Channel] = []
    var selectedChannelIDs: Set<UUID> = []
    var bodyText = ""
    var scheduleMode: ScheduleMode = .queue
    var customDate: Date = .now.addingTimeInterval(3_600)
    var selectedTab: Tab = .compose
    private(set) var pendingMedia: [PendingMedia] = []

    private(set) var isSaving = false
    private(set) var validationError: String?
    private(set) var nextQueueSlotText: String?

    enum Tab: Hashable {
        case compose
        case preview(Platform)
    }

    /// Per-platform character limits (X 280, Instagram 2 200, LinkedIn 3 000).
    static let limits: [Platform: Int] = [
        .instagram: 2200,
        .x: 280,
        .linkedin: 3000,
        .facebook: 63206,
        .tiktok: 2200,
        .youtube: 5000,
    ]

    init(
        channelRepository: ChannelRepository,
        postRepository: PostRepository,
        scheduleRepository: ScheduleRepository,
        presetDate: Date? = nil
    ) {
        self.channelRepository = channelRepository
        self.postRepository = postRepository
        self.scheduleRepository = scheduleRepository
        if let presetDate { customDate = presetDate; scheduleMode = .custom }
    }

    var isValid: Bool { validationError == nil && !selectedChannelIDs.isEmpty }

    func load() async {
        channels = (try? await channelRepository.loadChannels()) ?? []
        selectedChannelIDs = Set(channels.filter { $0.status == .connected }.map(\.id))
        await refreshQueueSlot()
    }

    func toggleChannel(_ channel: Channel) {
        if selectedChannelIDs.contains(channel.id) {
            selectedChannelIDs.remove(channel.id)
        } else {
            selectedChannelIDs.insert(channel.id)
        }
    }

    func addMedia(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                pendingMedia.append(PendingMedia(data: data))
            }
        }
    }

    func removeMedia(_ media: PendingMedia) {
        pendingMedia.removeAll { $0.id == media.id }
    }

    func selectedPlatforms() -> [Platform] {
        channels
            .filter { selectedChannelIDs.contains($0.id) }
            .map(\.platform)
    }

    func limit(for platform: Platform) -> Int {
        Self.limits[platform] ?? 280
    }

    func refreshQueueSlot() async {
        if let slot = try? await scheduleRepository.nextQueueSlot(after: .now) {
            nextQueueSlotText = slot.formatted(.dateTime.weekday(.wide).month().day().hour().minute())
        }
    }

    /// Validation per AppFLOW 2.3: at least one channel, text present, and no
    /// per-channel over-limit (which blocks scheduling for that channel).
    func validate() -> Bool {
        if selectedChannelIDs.isEmpty {
            validationError = "Select at least one channel."
            return false
        }
        if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationError = "Write something first — the post can't be empty."
            return false
        }
        if scheduleMode == .custom && customDate <= .now {
            validationError = "Pick a time in the future."
            return false
        }
        if scheduleMode != .now {
            for platform in selectedPlatforms() where bodyText.count > limit(for: platform) {
                validationError = "\(platform.displayName) allows \(limit(for: platform)) characters. Shorten the post or deselect it."
                return false
            }
        }
        validationError = nil
        return true
    }

    func save(asDraft: Bool) async -> Bool {
        guard validate() else { return false }
        isSaving = true
        defer { isSaving = false }
        let scheduledAt: Date?
        switch scheduleMode {
        case .queue:
            scheduledAt = try? await scheduleRepository.nextQueueSlot(after: .now)
        case .custom:
            scheduledAt = customDate
        case .now:
            scheduledAt = .now
        }
        let targets = channels
            .filter { selectedChannelIDs.contains($0.id) }
            .map { channel in
                PostTarget(
                    id: UUID(), channelID: channel.id, bodyOverride: nil,
                    status: asDraft ? .draft : .scheduled, scheduledAt: scheduledAt,
                    publishedAt: nil, attempts: 0, errorMessage: nil
                )
            }
        let post = Post(
            id: UUID(), body: bodyText, status: asDraft ? .draft : .scheduled,
            scheduleMode: asDraft ? nil : scheduleMode, scheduledAt: scheduledAt,
            publishedAt: nil, targets: targets, media: []
        )
        do {
            var saved = try await postRepository.save(
                post, as: asDraft ? .draft : .scheduled,
                scheduleMode: asDraft ? nil : scheduleMode,
                scheduledAt: scheduledAt
            )
            for media in pendingMedia {
                let asset = try await postRepository.attachMedia(
                    media.data, fileName: "photo.jpg", kind: .image, to: saved
                )
                saved.media.append(asset)
            }
            return true
        } catch {
            validationError = "Couldn't save the post. Try again."
            return false
        }
    }
}
