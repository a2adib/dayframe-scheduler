import SwiftUI

/// Queue screen, matching the Figma "Code" frame (node 4-3): logo mark + title
/// nav bar with a Channels pill, filter chips (All, Drafts, Channels),
/// failure triage banner, day grouping, swipe actions, skeleton, and empty state.
struct QueueView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: QueueViewModel?
    @State private var postToConfirmDelete: Post?
    @State private var showsChannels = false
    @State private var editingDraft: Post?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model: model)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(DayframeColor.background)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
            .navigationDestination(for: UUID.self) { postID in
                if let model, let post = model.posts.first(where: { $0.id == postID }) ?? model.drafts.first(where: { $0.id == postID }) {
                    PostDetailView(
                        post: post,
                        platforms: post.targets.compactMap { model.platform(for: $0) },
                        onDeleted: { Task { await model.load() } },
                        onRescheduled: { _ in Task { await model.load() } }
                    )
                }
            }
            .sheet(isPresented: $showsChannels) {
                NavigationStack {
                    ConnectChannelsView(onFinished: { showsChannels = false })
                        .presentationDetents([.large])
                }
            }
            .fullScreenCover(item: $editingDraft) { draft in
                ComposerView(editingPost: draft, onSaved: {
                    editingDraft = nil
                    Task { await model?.load() }
                })
            }
            .alert(
                "Delete this post?",
                isPresented: Binding(
                    get: { postToConfirmDelete != nil },
                    set: { if !$0 { postToConfirmDelete = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let post = postToConfirmDelete {
                        Task { await model?.delete(post) }
                    }
                    postToConfirmDelete = nil
                }
                Button("Cancel", role: .cancel) { postToConfirmDelete = nil }
            } message: {
                Text("This removes the post for all of its channels.")
            }
            .task {
                if model == nil {
                    let viewModel = QueueViewModel(
                        channelRepository: environment.channelRepository,
                        postRepository: environment.postRepository
                    )
                    model = viewModel
                    await viewModel.load()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: DayframeSpacing.sm) {
                DayframeLogoMark(size: 24)
                Text("Queue")
                    .font(DayframeFont.largeTitle(28))
                    .foregroundStyle(DayframeColor.textPrimary)
            }
            .accessibilityElement(children: .combine)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            SecondaryButton(title: "Channels") { showsChannels = true }
        }
    }

    @ViewBuilder
    private func content(model: QueueViewModel) -> some View {
        if model.isLoading {
            loadingList
        } else if let error = model.loadError {
            errorView(message: error, model: model)
        } else if model.filteredPosts.isEmpty {
            emptyView(model: model)
        } else {
            queueList(model: model)
        }
    }

    private var loadingList: some View {
        VStack(spacing: DayframeSpacing.lg) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonView(height: 120, cornerRadius: DayframeRadius.card)
            }
            Spacer()
        }
        .padding(DayframeSpacing.lg)
        .accessibilityLabel("Loading queue")
    }

    private func errorView(message: String, model: QueueViewModel) -> some View {
        VStack(spacing: DayframeSpacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(Color("Warning"))
            Text(message)
                .font(DayframeFont.body)
                .foregroundStyle(DayframeColor.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Retry", action: { Task { await model.load() } })
                .frame(maxWidth: 200)
        }
        .padding(DayframeSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyView(model: QueueViewModel) -> some View {
        VStack {
            filterChips(model: model)
                .padding(.horizontal, DayframeSpacing.lg)
                .padding(.top, DayframeSpacing.sm)

            if case .drafts = model.currentFilter {
                EmptyStateView(
                    title: "No drafts",
                    message: "Save drafts from the composer to review and schedule later.",
                    actionTitle: "Create post",
                    action: {}
                )
            } else {
                EmptyStateView(
                    title: "Nothing planned",
                    message: "Nothing planned. Frame your day.",
                    actionTitle: "Create post",
                    action: {}
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func queueList(model: QueueViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DayframeSpacing.lg) {
                if !model.failedPosts.isEmpty, model.currentFilter != .drafts {
                    failedPostsBanner(model: model)
                }

                filterChips(model: model)

                ForEach(model.daySections, id: \.title) { section in
                    daySection(title: section.title, posts: section.posts, model: model)
                }
            }
            .padding(DayframeSpacing.lg)
        }
        .refreshable { await model.load() }
    }

    private func failedPostsBanner(model: QueueViewModel) -> some View {
        NavigationLink(value: model.failedPosts.first?.id) {
            HStack(spacing: DayframeSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color("Danger"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.failedPosts.count) post\(model.failedPosts.count == 1 ? "" : "s") failed to publish")
                        .font(DayframeFont.headline)
                        .foregroundStyle(Color("Danger"))
                    Text("Tap to review the failure reason and retry.")
                        .font(.system(size: 12))
                        .foregroundStyle(DayframeColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DayframeColor.textSecondary)
            }
            .padding(DayframeSpacing.md)
            .background(Color("Danger").opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func filterChips(model: QueueViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DayframeSpacing.sm) {
                chip(title: "All Channels", isSelected: model.currentFilter == .all) {
                    model.currentFilter = .all
                }

                let draftTitle = model.drafts.isEmpty ? "Drafts" : "Drafts (\(model.drafts.count))"
                chip(title: draftTitle, isSelected: model.currentFilter == .drafts) {
                    model.currentFilter = .drafts
                }

                ForEach(model.channels, id: \.id) { channel in
                    chip(
                        title: channel.platform.displayName,
                        isSelected: model.currentFilter == .channel(channel.platform)
                    ) {
                        model.currentFilter = .channel(channel.platform)
                    }
                }
            }
        }
        .accessibilityLabel("Queue filters")
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DayframeFont.chip)
                .multilineTextAlignment(.center)
                .foregroundStyle(isSelected ? .white : DayframeColor.textSecondary)
                .padding(.horizontal, DayframeSpacing.lg)
                .padding(.vertical, DayframeSpacing.sm + 2)
                .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : AnyShapeStyle(DayframeColor.surface))
                .clipShape(Capsule())
        }
        .accessibilityLabel("Filter by \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func daySection(title: String, posts: [Post], model: QueueViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.lg) {
            SectionHeader(title: title, trailingText: "\(posts.count) post\(posts.count == 1 ? "" : "s")")
            ForEach(posts) { post in
                timelineRow(post: post, isLast: post.id == posts.last?.id, model: model)
            }
        }
    }

    private func timelineRow(post: Post, isLast: Bool, model: QueueViewModel) -> some View {
        HStack(alignment: .top, spacing: DayframeSpacing.md) {
            VStack(spacing: 0) {
                Circle()
                    .fill(DayframeColor.primary)
                    .frame(width: 10, height: 10)
                if !isLast {
                    Rectangle()
                        .fill(DayframeColor.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)
            .padding(.top, 18)
            .accessibilityHidden(true)

            swipeableCard(post: post, model: model)
        }
    }

    private func swipeableCard(post: Post, model: QueueViewModel) -> some View {
        Group {
            if post.status == .draft {
                Button {
                    editingDraft = post
                } label: {
                    postCard(for: post, model: model)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: post.id) {
                    postCard(for: post, model: model)
                }
                .buttonStyle(.plain)
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                postToConfirmDelete = post
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                Task { await model.duplicate(post) }
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(DayframeColor.primary)
        }
    }

    private func postCard(for post: Post, model: QueueViewModel) -> some View {
        PostCard(
            platforms: post.targets.compactMap { model.platform(for: $0) },
            timeText: post.scheduledAt?.formatted(.dateTime.hour().minute()) ?? (post.status == .draft ? "Draft" : ""),
            status: post.status,
            bodyText: post.body,
            mediaCaption: post.media.first?.storagePath
        )
    }
}

#Preview("Queue") {
    QueueView()
        .environment(AppEnvironment())
}
