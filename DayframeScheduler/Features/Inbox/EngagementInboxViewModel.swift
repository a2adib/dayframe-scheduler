import Foundation
import Observation

enum InboxFilter: String, CaseIterable, Identifiable {
    case unreplied = "Unreplied"
    case all = "All"
    case starred = "Starred"

    var id: String { rawValue }
}

@Observable
@MainActor
final class EngagementInboxViewModel {
    private let engagementRepository: EngagementRepository
    private let channelRepository: ChannelRepository

    private(set) var items: [EngagementItem] = []
    private(set) var channels: [Channel] = []
    private(set) var isLoading = false
    private(set) var isSendingReply = false
    var currentFilter: InboxFilter = .unreplied
    var selectedItem: EngagementItem?
    var replyText: String = ""

    init(
        engagementRepository: EngagementRepository,
        channelRepository: ChannelRepository
    ) {
        self.engagementRepository = engagementRepository
        self.channelRepository = channelRepository
    }

    var unrepliedCount: Int {
        items.filter { !$0.isReplied }.count
    }

    var filteredItems: [EngagementItem] {
        switch currentFilter {
        case .unreplied:
            return items.filter { !$0.isReplied }
        case .all:
            return items
        case .starred:
            return items.filter { $0.isStarred }
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        items = (try? await engagementRepository.loadItems()) ?? []
        channels = (try? await channelRepository.loadChannels()) ?? []
        if selectedItem == nil, let first = filteredItems.first {
            selectedItem = first
        }
    }

    func selectItem(_ item: EngagementItem) {
        selectedItem = item
        replyText = ""
    }

    func sendReply(to item: EngagementItem, text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSendingReply = true
        defer { isSendingReply = false }

        if let updated = try? await engagementRepository.sendReply(itemID: item.id, replyText: text) {
            items = items.map { $0.id == item.id ? updated : $0 }
            if selectedItem?.id == item.id {
                selectedItem = updated
            }
            replyText = ""
        }
    }

    func toggleStar(for item: EngagementItem) async {
        if let updated = try? await engagementRepository.toggleStar(itemID: item.id) {
            items = items.map { $0.id == item.id ? updated : $0 }
            if selectedItem?.id == item.id {
                selectedItem = updated
            }
        }
    }

    func toggleReplied(for item: EngagementItem) async {
        let newStatus = !item.isReplied
        if let updated = try? await engagementRepository.markReplied(itemID: item.id, isReplied: newStatus) {
            items = items.map { $0.id == item.id ? updated : $0 }
            if selectedItem?.id == item.id {
                selectedItem = updated
            }
        }
    }

    /// Smart 1-click AI-suggested reply chips tailored to the comment content and sentiment.
    func suggestedReplies(for item: EngagementItem) -> [String] {
        let text = item.content.lowercased()
        if text.contains("how") || text.contains("setup") || text.contains("template") || text.contains("tool") {
            return [
                "Great question! I just dropped the full guide link in our bio 🔗",
                "Appreciate the question! We built a step-by-step breakdown on our profile.",
                "Happy to share! Dropping the setup details in my next post 🙌"
            ]
        } else if text.contains("love") || text.contains("saved") || text.contains("recommend") || text.contains("great") || text.contains("fire") {
            return [
                "Thank you so much! Really glad this helped 🙌",
                "Appreciate the love! More breakdowns dropping this Friday ✨",
                "Means a lot, thanks for following the journey! 🚀"
            ]
        } else {
            return [
                "Thanks for sharing your perspective! 🙌",
                "Spot on! Really appreciate your thoughts.",
                "Glad you enjoyed this update! 🚀"
            ]
        }
    }
}
