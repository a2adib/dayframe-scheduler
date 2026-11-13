import SwiftUI

/// Queue screen, matching the Figma "Code" frame (node 4-3): logo mark + title
/// nav bar with a Channels pill, filter chips, posts grouped by day with a
/// timeline connector, swipe actions, skeleton, and empty state (AppFLOW 2.5).
struct QueueView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: QueueViewModel?
    @State private var postToConfirmDelete: Post?
    @State private var showsChannels = false

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
                if let model, let post = model.posts.first(where: { $0.id == postID }) {
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
        } else if model.posts.isEmpty {
            EmptyStateView(
                title: "Nothing planned",
                message: "Nothing planned. Frame your day.",
                actionTitle: "Create post",
                action: {}
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func queueList(model: QueueViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DayframeSpacing.lg) {
                filterChips(model: model)
                ForEach(model.daySections, id: \.title) { section in
                    daySection(title: section.title, posts: section.posts, model: model)
                }
            }
            .padding(DayframeSpacing.lg)
        }
        .refreshable { await model.load() }
    }

    private func filterChips(model: QueueViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DayframeSpacing.sm) {
                chip(title: "All Channels", isSelected: model.selectedPlatform == nil) {
                    model.selectedPlatform = nil
                }
                ForEach(model.channels, id: \.id) { channel in
                    chip(
                        title: channel.platform.displayName,
                        isSelected: model.selectedPlatform == channel.platform
                    ) {
                        model.selectedPlatform = channel.platform
                    }
                }
            }
        }
        .accessibilityLabel("Channel filter")
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
        NavigationLink(value: post.id) {
            PostCard(
                platforms: post.targets.compactMap { model.platform(for: $0) },
                timeText: post.scheduledAt?.formatted(.dateTime.hour().minute()) ?? "",
                status: post.status,
                bodyText: post.body,
                mediaCaption: post.media.first?.storagePath
            )
        }
        .buttonStyle(.plain)
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
}

#Preview("Queue") {
    QueueView()
        .environment(AppEnvironment())
}

#Preview("Queue dark") {
    QueueView()
        .environment(AppEnvironment())
        .environment(\.colorScheme, .dark)
}
