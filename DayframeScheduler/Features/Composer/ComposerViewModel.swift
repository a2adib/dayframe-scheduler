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

    enum PublishingAction: String, CaseIterable, Identifiable {
        case addToQueue = "Add to Queue"
        case schedule = "Schedule Post"
        case draft = "Save as Draft"
        case publishNow = "Publish Now"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .addToQueue: "tray.and.arrow.down.fill"
            case .schedule: "calendar.badge.clock"
            case .draft: "doc.text.fill"
            case .publishNow: "paperplane.fill"
            }
        }
    }

    private let channelRepository: ChannelRepository
    private let postRepository: PostRepository
    private let scheduleRepository: ScheduleRepository
    let editingPost: Post?

    private(set) var channels: [Channel] = []
    var selectedChannelIDs: Set<UUID> = []
    var bodyText = ""
    var bodyOverrides: [Platform: String] = [:]
    var firstComment = ""
    var firstCommentOverrides: [Platform: String] = [:]
    var publishingAction: PublishingAction = .addToQueue
    var scheduleMode: ScheduleMode = .queue
    var customDate: Date = .now.addingTimeInterval(3_600)
    var selectedTab: Tab = .compose
    var showsFirstCommentField = false
    var showsFeedGridPreview = false
    private(set) var pendingMedia: [PendingMedia] = []

    private(set) var isSaving = false
    private(set) var validationError: String?
    private(set) var channelsLoadFailed = false
    private(set) var nextQueueSlotText: String?

    enum Tab: Hashable {
        case compose
        case preview(Platform)
    }

    /// Per-platform character limits (X 280, Instagram 2 200, LinkedIn 3 000, Threads 500, TikTok 2 200).
    static let limits: [Platform: Int] = [
        .instagram: 2200,
        .x: 280,
        .linkedin: 3000,
        .threads: 500,
        .facebook: 63206,
        .tiktok: 2200,
        .youtube: 5000,
    ]

    init(
        channelRepository: ChannelRepository,
        postRepository: PostRepository,
        scheduleRepository: ScheduleRepository,
        editingPost: Post? = nil,
        presetDate: Date? = nil,
        prefillIdea: Idea? = nil,
        templatePost: Post? = nil
    ) {
        self.channelRepository = channelRepository
        self.postRepository = postRepository
        self.scheduleRepository = scheduleRepository
        self.editingPost = editingPost

        if let editingPost {
            self.bodyText = editingPost.body
            self.firstComment = editingPost.firstComment ?? ""
            self.showsFirstCommentField = !self.firstComment.isEmpty
            self.scheduleMode = editingPost.scheduleMode ?? .custom
            self.customDate = editingPost.scheduledAt ?? .now.addingTimeInterval(3_600)
            if editingPost.status == .draft {
                self.publishingAction = .draft
            } else if editingPost.scheduleMode == .queue {
                self.publishingAction = .addToQueue
            } else {
                self.publishingAction = .schedule
            }
        } else if let templatePost {
            self.bodyText = templatePost.body
            self.firstComment = templatePost.firstComment ?? ""
            self.showsFirstCommentField = !self.firstComment.isEmpty
            self.publishingAction = .addToQueue
            self.scheduleMode = .queue
            self.selectedChannelIDs = Set(templatePost.targets.map(\.channelID))
        } else if let prefillIdea {
            var combined = prefillIdea.title
            if !prefillIdea.notes.isEmpty {
                combined += combined.isEmpty ? prefillIdea.notes : "\n\n\(prefillIdea.notes)"
            }
            if !prefillIdea.tags.isEmpty {
                let tagStr = prefillIdea.tags.map { $0.hasPrefix("#") ? $0 : "#\($0)" }.joined(separator: " ")
                combined += "\n\n\(tagStr)"
            }
            if let link = prefillIdea.link, !link.isEmpty {
                combined += "\n\n\(link)"
            }
            self.bodyText = combined
            self.publishingAction = .addToQueue
            self.scheduleMode = .queue
        } else if let presetDate {
            self.customDate = presetDate
            self.scheduleMode = .custom
            self.publishingAction = .schedule
        }
    }

    func prefill(with idea: Idea) {
        var combined = idea.title
        if !idea.notes.isEmpty {
            combined += combined.isEmpty ? idea.notes : "\n\n\(idea.notes)"
        }
        if !idea.tags.isEmpty {
            let tagStr = idea.tags.map { $0.hasPrefix("#") ? $0 : "#\($0)" }.joined(separator: " ")
            combined += "\n\n\(tagStr)"
        }
        if let link = idea.link, !link.isEmpty {
            combined += "\n\n\(link)"
        }
        self.bodyText = combined
        self.publishingAction = .addToQueue
        self.scheduleMode = .queue
    }

    var isValid: Bool { validationError == nil && !selectedChannelIDs.isEmpty }

    func load() async {
        do {
            channels = try await channelRepository.loadChannels()
            channelsLoadFailed = false
        } catch {
            channels = []
            channelsLoadFailed = true
            validationError = "Couldn't load your channels. Check your connection and try again."
        }
        if let editingPost {
            selectedChannelIDs = Set(editingPost.targets.map(\.channelID))
            for target in editingPost.targets {
                if let platform = channels.first(where: { $0.id == target.channelID })?.platform {
                    if let override = target.bodyOverride {
                        bodyOverrides[platform] = override
                    }
                    if let fComment = target.firstComment {
                        firstCommentOverrides[platform] = fComment
                    }
                }
            }
        } else if selectedChannelIDs.isEmpty {
            selectedChannelIDs = Set(channels.filter { $0.status == .connected && !$0.isPaused }.map(\.id))
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

    // MARK: - Master-to-Channel Sync & Override

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

    func isSyncedWithMaster(for platform: Platform) -> Bool {
        bodyOverrides[platform] == nil
    }

    func syncWithMaster(for platform: Platform) {
        bodyOverrides.removeValue(forKey: platform)
    }

    // MARK: - First Comment Management

    func firstCommentFor(platform: Platform) -> String {
        firstCommentOverrides[platform] ?? firstComment
    }

    func setFirstCommentOverride(_ text: String, for platform: Platform) {
        firstCommentOverrides[platform] = text
    }

    func clearFirstCommentOverride(for platform: Platform) {
        firstCommentOverrides.removeValue(forKey: platform)
    }

    func hasFirstCommentOverride(for platform: Platform) -> Bool {
        firstCommentOverrides[platform] != nil
    }

    // MARK: - Media

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
    /// per-channel over-limit.
    func validate(asDraft: Bool = false) -> Bool {
        // Without the channel list we can't build targets; saving an edit now
        // would silently drop every channel from the post.
        if channelsLoadFailed || (!selectedChannelIDs.isEmpty && selectedPlatforms().isEmpty) {
            validationError = "Couldn't load your channels. Check your connection and try again."
            return false
        }
        if !asDraft && selectedChannelIDs.isEmpty {
            validationError = "Select at least one channel."
            return false
        }
        if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationError = "Write something first — the post can't be empty."
            return false
        }
        if !asDraft && publishingAction == .schedule && customDate <= .now {
            validationError = "Pick a time in the future."
            return false
        }
        if !asDraft {
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

    // MARK: - Submit Flow Supporting All 4 Publishing Actions

    func submit() async -> Bool {
        switch publishingAction {
        case .addToQueue:
            scheduleMode = .queue
            return await save(asDraft: false)
        case .schedule:
            scheduleMode = .custom
            return await save(asDraft: false)
        case .draft:
            return await save(asDraft: true)
        case .publishNow:
            scheduleMode = .now
            return await save(asDraft: false)
        }
    }

    func save(asDraft: Bool) async -> Bool {
        guard validate(asDraft: asDraft) else { return false }
        isSaving = true
        defer { isSaving = false }

        let scheduledAt: Date?
        let resolvedMode: ScheduleMode?
        if asDraft {
            scheduledAt = nil
            resolvedMode = nil
        } else {
            switch publishingAction {
            case .addToQueue:
                do {
                    scheduledAt = try await scheduleRepository.nextQueueSlot(after: .now)
                } catch {
                    validationError = "Couldn't find your next queue slot. Try again or pick a time."
                    return false
                }
                resolvedMode = .queue
            case .schedule:
                scheduledAt = customDate
                resolvedMode = .custom
            case .publishNow:
                scheduledAt = .now
                resolvedMode = .now
            case .draft:
                scheduledAt = nil
                resolvedMode = nil
            }
        }

        let cleanMasterComment = firstComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasMasterComment = !cleanMasterComment.isEmpty

        let targets = channels
            .filter { selectedChannelIDs.contains($0.id) }
            .map { channel in
                let targetComment = firstCommentOverrides[channel.platform] ?? (hasMasterComment ? cleanMasterComment : nil)
                return PostTarget(
                    id: UUID(),
                    channelID: channel.id,
                    bodyOverride: bodyOverrides[channel.platform],
                    firstComment: targetComment,
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
                scheduleMode: resolvedMode,
                scheduledAt: scheduledAt,
                publishedAt: nil,
                targets: targets,
                media: [],
                firstComment: hasMasterComment ? cleanMasterComment : nil
            )
            postToPersist.body = bodyText
            postToPersist.firstComment = hasMasterComment ? cleanMasterComment : nil
            postToPersist.targets = targets

            let saved: Post
            // "Publish now" is a target due immediately: publish-due only claims
            // `scheduled` targets, so `publishing` here would never go out.
            let targetStatus: PostStatus = asDraft ? .draft : .scheduled
            if editingPost != nil {
                saved = try await postRepository.update(
                    postToPersist,
                    as: targetStatus,
                    scheduleMode: resolvedMode,
                    scheduledAt: scheduledAt
                )
            } else {
                saved = try await postRepository.save(
                    postToPersist,
                    as: targetStatus,
                    scheduleMode: resolvedMode,
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
