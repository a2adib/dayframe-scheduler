import SwiftUI

/// Unified Community Engagement Inbox:
/// - Cross-platform comment and mention feed (Instagram, X, LinkedIn, Threads, Facebook)
/// - Two-pane responsive inbox: comment feed list + post context and reply thread
/// - Triage filters: Unreplied, All, Starred
/// - Inline reply submission and 1-click AI-suggested quick reply chips
struct EngagementInboxView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: EngagementInboxViewModel?

    var body: some View {
        Group {
            if let model {
                inboxContent(model: model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DayframeColor.background)
        .navigationTitle("Community Inbox")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                let viewModel = EngagementInboxViewModel(
                    engagementRepository: environment.engagementRepository,
                    channelRepository: environment.channelRepository
                )
                model = viewModel
                await viewModel.load()
            }
        }
    }

    private func inboxContent(model: EngagementInboxViewModel) -> some View {
        VStack(spacing: 0) {
            // Triage Filter Bar
            filterBar(model: model)

            Divider()

            if model.filteredItems.isEmpty {
                emptyInboxView(model: model)
            } else {
                // Two-Pane Responsive Layout (NavigationSplitView or Stack with selection)
                GeometryReader { geo in
                    if geo.size.width > 700 {
                        // Wide Screen: Dual Pane Side-by-Side
                        HStack(spacing: 0) {
                            itemsList(model: model)
                                .frame(width: 320)

                            Divider()

                            if let selected = model.selectedItem {
                                detailPane(item: selected, model: model)
                            } else {
                                selectPromptView
                            }
                        }
                    } else {
                        // Mobile Screen: Feed with selectable item sheet/view
                        ScrollView {
                            LazyVStack(spacing: DayframeSpacing.md) {
                                ForEach(model.filteredItems) { item in
                                    mobileItemCard(item: item, model: model)
                                }
                            }
                            .padding(DayframeSpacing.md)
                        }
                    }
                }
            }
        }
    }

    private func filterBar(model: EngagementInboxViewModel) -> some View {
        HStack(spacing: DayframeSpacing.sm) {
            ForEach(InboxFilter.allCases) { filter in
                let isSelected = model.currentFilter == filter
                Button {
                    model.currentFilter = filter
                } label: {
                    HStack(spacing: 4) {
                        Text(filter.rawValue)
                        if filter == .unreplied && model.unrepliedCount > 0 {
                            Text("\(model.unrepliedCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(isSelected ? DayframeColor.primary : .white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(isSelected ? Color.white : DayframeColor.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .font(DayframeFont.chip)
                    .foregroundStyle(isSelected ? .white : DayframeColor.textSecondary)
                    .padding(.horizontal, DayframeSpacing.md)
                    .padding(.vertical, DayframeSpacing.xs + 2)
                    .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : AnyShapeStyle(DayframeColor.surface))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, DayframeSpacing.lg)
        .padding(.vertical, DayframeSpacing.sm)
    }

    // MARK: - Left Pane: Comment Feed List

    private func itemsList(model: EngagementInboxViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.filteredItems) { item in
                    let isSelected = model.selectedItem?.id == item.id
                    Button {
                        model.selectItem(item)
                    } label: {
                        HStack(alignment: .top, spacing: DayframeSpacing.sm) {
                            ZStack(alignment: .bottomTrailing) {
                                ChannelAvatar(platform: item.platform, size: 36, showsBadge: false)
                                PlatformBadge(platform: item.platform, size: 14)
                                    .offset(x: 3, y: 3)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(item.authorName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(DayframeColor.textPrimary)
                                        .lineLimit(1)

                                    Spacer()

                                    Text(item.createdAt.formatted(.dateTime.hour().minute()))
                                        .font(.system(size: 11))
                                        .foregroundStyle(DayframeColor.textSecondary)
                                }

                                Text(item.content)
                                    .font(.system(size: 12))
                                    .foregroundStyle(DayframeColor.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                HStack {
                                    if !item.isReplied {
                                        Circle()
                                            .fill(DayframeColor.primary)
                                            .frame(width: 6, height: 6)
                                        Text("Needs reply")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(DayframeColor.primary)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color("Success"))
                                        Text("Replied")
                                            .font(.system(size: 10))
                                            .foregroundStyle(DayframeColor.textTertiary)
                                    }
                                    Spacer()
                                    if item.isStarred {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.orange)
                                    }
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(DayframeSpacing.md)
                        .background(isSelected ? DayframeColor.primary.opacity(0.08) : DayframeColor.background)
                    }
                    .buttonStyle(.plain)

                    Divider()
                }
            }
        }
    }

    // MARK: - Right Pane: Detail & Reply Box

    private func detailPane(item: EngagementItem, model: EngagementInboxViewModel) -> some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DayframeSpacing.lg) {
                    // Original Post Context Header
                    VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                        HStack(spacing: 6) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 12))
                                .foregroundStyle(DayframeColor.primary)
                            Text("ORIGINAL POST CONTEXT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DayframeColor.textSecondary)
                            Spacer()
                            PlatformBadge(platform: item.platform, size: 14)
                        }

                        Text(item.postSnippet ?? "Scheduled post: 'Framing your day before opening your feeds changes everything...'")
                            .font(.system(size: 13))
                            .foregroundStyle(DayframeColor.textPrimary)
                            .lineLimit(3)
                    }
                    .padding(DayframeSpacing.md)
                    .background(DayframeColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))

                    // Received Comment Thread Card
                    VStack(alignment: .leading, spacing: DayframeSpacing.md) {
                        HStack(spacing: DayframeSpacing.sm) {
                            ChannelAvatar(platform: item.platform, size: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(item.authorName)
                                        .font(DayframeFont.headline)
                                        .foregroundStyle(DayframeColor.textPrimary)
                                    Text(item.authorHandle)
                                        .font(.system(size: 13))
                                        .foregroundStyle(DayframeColor.textSecondary)
                                }
                                Text("Commented • \(item.createdAt.formatted(.dateTime.weekday().hour().minute()))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DayframeColor.textSecondary)
                            }

                            Spacer()

                            Button {
                                Task { await model.toggleStar(for: item) }
                            } label: {
                                Image(systemName: item.isStarred ? "star.fill" : "star")
                                    .font(.system(size: 16))
                                    .foregroundStyle(item.isStarred ? Color.orange : DayframeColor.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(item.content)
                            .font(DayframeFont.body)
                            .foregroundStyle(DayframeColor.textPrimary)

                        // Previous Reply If Sent
                        if let reply = item.replyText, !reply.isEmpty {
                            HStack(alignment: .top, spacing: DayframeSpacing.sm) {
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color("Success"))
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Your Reply")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color("Success"))
                                        if let repliedAt = item.repliedAt {
                                            Text("• \(repliedAt.formatted(.dateTime.hour().minute()))")
                                                .font(.system(size: 10))
                                                .foregroundStyle(DayframeColor.textSecondary)
                                        }
                                    }
                                    Text(reply)
                                        .font(.system(size: 13))
                                        .foregroundStyle(DayframeColor.textPrimary)
                                }
                            }
                            .padding(DayframeSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color("Success").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                        }
                    }
                    .padding(DayframeSpacing.md)
                    .background(DayframeColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                            .strokeBorder(DayframeColor.border, lineWidth: 1)
                    )

                    // 1-Click AI-Suggested Reply Chips
                    VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundStyle(DayframeColor.brandGradient)
                            Text("1-Click Smart Replies")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DayframeColor.primary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DayframeSpacing.sm) {
                                ForEach(model.suggestedReplies(for: item), id: \.self) { chip in
                                    Button {
                                        model.replyText = chip
                                    } label: {
                                        Text(chip)
                                            .font(.system(size: 12))
                                            .foregroundStyle(DayframeColor.textPrimary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(DayframeColor.surface)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().strokeBorder(DayframeColor.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(DayframeSpacing.lg)
            }

            Divider()

            // Inline Reply Box
            HStack(spacing: DayframeSpacing.sm) {
                TextField("Write a reply to \(item.authorName)...", text: $model.replyText, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(1...4)
                    .padding(DayframeSpacing.sm)
                    .background(DayframeColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))

                Button {
                    Task {
                        await model.sendReply(to: item, text: model.replyText)
                    }
                } label: {
                    if model.isSendingReply {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 36, height: 36)
                            .background(DayframeColor.primary)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(model.replyText.isEmpty ? DayframeColor.textTertiary : DayframeColor.primary)
                    }
                }
                .disabled(model.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSendingReply)
                .buttonStyle(.plain)
            }
            .padding(DayframeSpacing.md)
            .background(DayframeColor.background)
        }
    }

    // MARK: - Mobile Card Layout

    private func mobileItemCard(item: EngagementItem, model: EngagementInboxViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
            HStack(spacing: DayframeSpacing.sm) {
                ZStack(alignment: .bottomTrailing) {
                    ChannelAvatar(platform: item.platform, size: 38, showsBadge: false)
                    PlatformBadge(platform: item.platform, size: 14)
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.authorName)
                        .font(DayframeFont.headline)
                        .foregroundStyle(DayframeColor.textPrimary)
                    Text("\(item.authorHandle) • \(item.createdAt.formatted(.dateTime.weekday().hour().minute()))")
                        .font(.system(size: 11))
                        .foregroundStyle(DayframeColor.textSecondary)
                }

                Spacer()

                Button {
                    Task { await model.toggleStar(for: item) }
                } label: {
                    Image(systemName: item.isStarred ? "star.fill" : "star")
                        .foregroundStyle(item.isStarred ? Color.orange : DayframeColor.textSecondary)
                }
            }

            Text(item.content)
                .font(DayframeFont.body)
                .foregroundStyle(DayframeColor.textPrimary)

            if let reply = item.replyText {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("Success"))
                    Text(reply)
                        .font(.system(size: 12))
                        .foregroundStyle(DayframeColor.textSecondary)
                }
                .padding(8)
                .background(Color("Success").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Quick reply chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.suggestedReplies(for: item).prefix(2), id: \.self) { chip in
                        Button {
                            Task { await model.sendReply(to: item, text: chip) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9))
                                Text(chip)
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(DayframeColor.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DayframeColor.primary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(DayframeSpacing.md)
        .background(DayframeColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
    }

    private var selectPromptView: some View {
        VStack(spacing: DayframeSpacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(DayframeColor.textTertiary)
            Text("Select a conversation")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)
            Text("Respond to incoming comments and build audience loyalty.")
                .font(.system(size: 13))
                .foregroundStyle(DayframeColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyInboxView(model: EngagementInboxViewModel) -> some View {
        VStack(spacing: DayframeSpacing.md) {
            Image(systemName: "tray.fill")
                .font(.system(size: 44))
                .foregroundStyle(DayframeColor.primary.opacity(0.4))
            Text("Inbox Zero! 🎉")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)
            Text("All caught up with incoming comments across your channels.")
                .font(.system(size: 13))
                .foregroundStyle(DayframeColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview("EngagementInbox") {
    NavigationStack {
        EngagementInboxView()
            .environment(AppEnvironment())
    }
}
