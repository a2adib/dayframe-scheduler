import SwiftUI

/// Post detail (AppFLOW §1, UI_Spec §4.6): full preview, status, channels,
/// time, error diagnosis, and edit / reschedule / retry / delete actions.
struct PostDetailView: View {
    var post: Post
    var platforms: [Platform]
    var onDeleted: () -> Void
    var onRescheduled: (Post) -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var showsDeleteConfirmation = false
    @State private var showsReschedule = false
    @State private var showsComposer = false
    @State private var isRetrying = false
    @State private var rescheduleDate: Date = .now.addingTimeInterval(3_600)
    @State private var updatedPost: Post?

    private var displayPost: Post { updatedPost ?? post }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DayframeSpacing.xl) {
                if displayPost.status == .failed {
                    failureBanner
                }
                preview
                meta
                actions
            }
            .padding(DayframeSpacing.lg)
        }
        .background(DayframeColor.background)
        .navigationTitle("Post Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Published or in-flight posts can't be edited: re-saving would
                // send them to the platform a second time.
                if displayPost.status != .published && displayPost.status != .publishing {
                    Button("Edit") {
                        showsComposer = true
                    }
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.primary)
                    .accessibilityLabel("Edit post")
                }
            }
        }
        .fullScreenCover(isPresented: $showsComposer) {
            ComposerView(editingPost: displayPost, onSaved: {
                showsComposer = false
                onRescheduled(displayPost)
            })
        }
        .confirmationDialog(
            "Delete this post?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deletePost() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the post for all of its channels.")
        }
        .sheet(isPresented: $showsReschedule) {
            rescheduleSheet
        }
    }

    private var failureBanner: some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
            Label("Publishing failed", systemImage: "exclamationmark.triangle.fill")
                .font(DayframeFont.headline)
                .foregroundStyle(Color("Danger"))
            if let errorMsg = displayPost.targets.compactMap(\.errorMessage).first {
                Text(errorMsg)
                    .font(.system(size: 13))
                    .foregroundStyle(DayframeColor.textSecondary)
            } else {
                Text("The post encountered an error when publishing to your accounts. You can tap 'Retry now' to try publishing again immediately.")
                    .font(.system(size: 13))
                    .foregroundStyle(DayframeColor.textSecondary)
            }
        }
        .padding(DayframeSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("Danger").opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
    }

    private var preview: some View {
        PlatformPreviewCard(
            platform: platforms.first ?? .instagram,
            bodyText: displayPost.body,
            firstComment: displayPost.firstComment
        )
        .padding(.horizontal, DayframeSpacing.lg)
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            HStack {
                StatusChip(status: displayPost.status)
                Spacer()
                Text(displayPost.scheduledAt?.formatted(.dateTime.weekday(.wide).month().day().hour().minute()) ?? "Not scheduled")
                    .font(DayframeFont.chip)
                    .foregroundStyle(DayframeColor.textSecondary)
            }
            HStack(spacing: DayframeSpacing.sm) {
                ForEach(platforms, id: \.self) { platform in
                    ChannelAvatar(platform: platform, size: 36)
                }
                Text("Publishing to \(platforms.count) channel\(platforms.count == 1 ? "" : "s")")
                    .font(DayframeFont.chip)
                    .foregroundStyle(DayframeColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: DayframeSpacing.md) {
            if displayPost.status == .failed {
                PrimaryButton(title: isRetrying ? "Retrying…" : "Retry now", systemImage: "arrow.clockwise") {
                    retryPost()
                }
                .disabled(isRetrying)
            }

            if displayPost.status == .draft {
                PrimaryButton(title: "Finish & schedule", systemImage: "pencil") {
                    showsComposer = true
                }
            } else {
                SecondaryButton(title: "Reschedule", systemImage: "clock") {
                    rescheduleDate = displayPost.scheduledAt ?? .now.addingTimeInterval(3_600)
                    showsReschedule = true
                }
            }

            PrimaryButton(title: "Delete", systemImage: "trash") {
                showsDeleteConfirmation = true
            }
            .tint(Color("Danger"))
        }
    }

    private var rescheduleSheet: some View {
        VStack(spacing: DayframeSpacing.xl) {
            DatePicker(
                "New time",
                selection: $rescheduleDate,
                in: .now...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .tint(DayframeColor.primary)
            PrimaryButton(title: "Reschedule") {
                Task {
                    if let updated = try? await environment.postRepository.reschedule(displayPost, to: rescheduleDate) {
                        updatedPost = updated
                        onRescheduled(updated)
                    }
                    showsReschedule = false
                }
            }
        }
        .padding(DayframeSpacing.xl)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func retryPost() {
        isRetrying = true
        Task {
            defer { isRetrying = false }
            if let retried = try? await environment.postRepository.retry(displayPost) {
                updatedPost = retried
                onRescheduled(retried)
            }
        }
    }

    private func deletePost() {
        Task {
            try? await environment.postRepository.delete(displayPost)
            onDeleted()
            dismiss()
        }
    }
}

#Preview("PostDetail") {
    NavigationStack {
        PostDetailView(
            post: MockData.posts().first ?? Post(id: UUID(), body: "Test", status: .scheduled, scheduleMode: .queue, scheduledAt: .now, publishedAt: nil, targets: [], media: []),
            platforms: [.x, .linkedin],
            onDeleted: {},
            onRescheduled: { _ in }
        )
    }
}
