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
    let editingPost: Post?

    private(set) var channels: [Channel] = []
    var selectedChannelIDs: Set<UUID> = []
    var bodyText = ""
    var bodyOverrides: [Platform: String] = [:]
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
        editingPost: Post? = nil,
        presetDate: Date? = nil
    ) {
        self.channelRepository = channelRepository
        self.postRepository = postRepository
        self.scheduleRepository = scheduleRepository
        self.editingPost = editingPost
        if let editingPost {
            self.bodyText = editingPost.body
            self.scheduleMode = editingPost.scheduleMode ?? .custom
            self.customDate = editingPost.scheduledAt ?? .now.addingTimeInterval(3_600)
        } else if let presetDate {
            self.customDate = presetDate
            self.scheduleMode = .custom
        }
    }

    var isValid: Bool { validationError == nil && !selectedChannelIDs.isEmpty }

    func load() async {
        channels = (try? await channelRepository.loadChannels()) ?? []
        if let editingPost {
            selectedChannelIDs = Set(editingPost.targets.map(\.channelID))
            for target in editingPost.targets {
                if let override = target.bodyOverride,
                   let platform = channels.first(where: { $0.id == target.channelID })?.platform {
                    bodyOverrides[platform] = override
                }
            }
        } else {
            selectedChannelIDs = Set(channels.filter { $0.status == .connected }.map(\.id))
        }
        await refreshQueueSlot()
    }

    func toggleChannel(_ channel: Channel) {
        if selectedChannelIDs.contains(channel.id) {
            selectedChannelIDs.remove(channel.id)
        } else {
            selectedChannelIDs.insert(channel.id)
        }
    }

    func bodyFor(platform: Platform) -> String {
        bodyOverrides[platform] ?? bodyText
    }

    func setOverride(_ text: String, for platform: Platform) {
        bodyOverrides[platform] = text
    }

    func clearOverride(for platform: Platform) {
        bodyOverrides.removeValue(forKey: platform)
    }

    func hasOverride(for platform: Platform) -> Bool {
        bodyOverrides[platform] != nil
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

    /// Validation per AppFLOW 2.3: at least one channel (for scheduled posts), text present, and no
    /// per-channel over-limit (which blocks scheduling for that channel).
    func validate(asDraft: Bool = false) -> Bool {
        if !asDraft && selectedChannelIDs.isEmpty {
            validationError = "Select at least one channel."
            return false
        }
        if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationError = "Write something first — the post can't be empty."
            return false
        }
        if !asDraft && scheduleMode == .custom && customDate <= .now {
            validationError = "Pick a time in the future."
            return false
        }
        if !asDraft && scheduleMode != .now {
            for platform in selectedPlatforms() {
                let text = bodyFor(platform: platform)
                if text.count > limit(for: platform) {
                    validationError = "\(platform.displayName) allows \(limit(for: platform)) characters. Shorten the post or deselect it."
                    return false
                }
            }
        }
        validationError = nil
        return true
    }

    func save(asDraft: Bool) async -> Bool {
        guard validate(asDraft: asDraft) else { return false }
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
                    id: UUID(),
                    channelID: channel.id,
                    bodyOverride: bodyOverrides[channel.platform],
                    status: asDraft ? .draft : .scheduled,
                    scheduledAt: scheduledAt,
                    publishedAt: nil,
                    attempts: 0,
                    errorMessage: nil
                )
            }
        do {
            var postToPersist = editingPost ?? Post(
                id: UUID(),
                body: bodyText,
                status: asDraft ? .draft : .scheduled,
                scheduleMode: asDraft ? nil : scheduleMode,
                scheduledAt: scheduledAt,
                publishedAt: nil,
                targets: targets,
                media: []
            )
            postToPersist.body = bodyText
            postToPersist.targets = targets

            let saved: Post
            if editingPost != nil {
                saved = try await postRepository.update(
                    postToPersist,
                    as: asDraft ? .draft : .scheduled,
                    scheduleMode: asDraft ? nil : scheduleMode,
                    scheduledAt: scheduledAt
                )
            } else {
                saved = try await postRepository.save(
                    postToPersist,
                    as: asDraft ? .draft : .scheduled,
                    scheduleMode: asDraft ? nil : scheduleMode,
                    scheduledAt: scheduledAt
                )
            }
            for media in pendingMedia {
                _ = try await postRepository.attachMedia(
                    media.data, fileName: "photo.jpg", kind: .image, to: saved
                )
            }
            return true
        } catch {
            print("[ComposerViewModel] Failed to save post: \(error)")
            validationError = error.localizedDescription
            return false
        }
    }
}
