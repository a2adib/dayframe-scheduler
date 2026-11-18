import PhotosUI
import SwiftUI
import UIKit

/// Smart Post Composer (AppFLOW 2.3, UI_Spec §4.4):
/// - Master-to-Channel Sync with per-network customization tabs
/// - Built-in AI Writing Toolbar (Tone rewrite, Viral hooks, Shorten/Expand, Auto-Hashtags)
/// - First Comment Automation (Instagram & LinkedIn auto-dispatch)
/// - Live Platform Previews tailored to each network + Instagram Feed Grid Preview
/// - 4 Flexible Publishing Actions: Add to Queue, Schedule Post, Save Draft, Publish Now
struct ComposerView: View {
    var editingPost: Post? = nil
    var presetDate: Date? = nil
    var prefillIdea: Idea? = nil
    var onSaved: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: ComposerViewModel?
    @State private var pickerSelection: [PhotosPickerItem] = []
    @FocusState private var editorFocused: Bool

    @State private var showingAISheet = false
    @State private var showingHashtagSheet = false
    @State private var showingEmojiSheet = false
    @State private var showingLinkAlert = false
    @State private var linkInput = ""
    @State private var showingGridPreview = false

    var body: some View {
        Group {
            if let model {
                content(model: model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DayframeColor.background)
            }
        }
        .task {
            if model == nil {
                let viewModel = ComposerViewModel(
                    channelRepository: environment.channelRepository,
                    postRepository: environment.postRepository,
                    scheduleRepository: environment.scheduleRepository,
                    editingPost: editingPost,
                    presetDate: presetDate,
                    prefillIdea: prefillIdea
                )
                model = viewModel
                await viewModel.load()
            }
        }
        .sheet(isPresented: $showingAISheet) {
            if let model {
                AIAssistantSheet(currentText: activeText(model: model)) { suggestion, isReplacement in
                    applyText(suggestion, isReplacement: isReplacement, model: model)
                }
            }
        }
        .sheet(isPresented: $showingHashtagSheet) {
            if let model {
                HashtagManagerSheet { tags in
                    appendSnippet(tags, model: model)
                }
            }
        }
        .sheet(isPresented: $showingEmojiSheet) {
            if let model {
                QuickEmojiSheet { emoji in
                    appendSnippet(emoji, model: model)
                }
            }
        }
        .sheet(isPresented: $showingGridPreview) {
            if let model {
                InstagramFeedGridPreviewSheet(
                    currentPostMedia: model.pendingMedia,
                    currentPostCaption: model.bodyFor(platform: .instagram),
                    handle: model.channels.first(where: { $0.platform == .instagram })?.handle ?? "@yourbrand"
                )
            }
        }
        .alert("Insert Link", isPresented: $showingLinkAlert) {
            TextField("https://example.com", text: $linkInput)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
            Button("Insert") {
                if let model, !linkInput.isEmpty {
                    appendSnippet(linkInput, model: model)
                    linkInput = ""
                }
            }
            Button("Cancel", role: .cancel) { linkInput = "" }
        } message: {
            Text("Add a link or URL to your post.")
        }
    }

    private func content(model: ComposerViewModel) -> some View {
        VStack(spacing: 0) {
            navBar(model: model)

            Divider()
                .overlay(DayframeColor.border)

            Picker("Tab", selection: Binding(
                get: { model.selectedTab },
                set: { model.selectedTab = $0 }
            )) {
                Text("Compose").tag(ComposerViewModel.Tab.compose)
                if !model.selectedPlatforms().isEmpty {
                    ForEach(model.selectedPlatforms(), id: \.self) { platform in
                        HStack(spacing: 4) {
                            Text(platform.displayName)
                            if model.hasOverride(for: platform) {
                                Image(systemName: "pencil.circle.fill")
                            }
                        }
                        .tag(ComposerViewModel.Tab.preview(platform))
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DayframeSpacing.lg)
            .padding(.vertical, DayframeSpacing.sm)
            .tint(DayframeColor.primary)

            if case .compose = model.selectedTab {
                composePane(model: model)
            } else if case .preview(let platform) = model.selectedTab {
                PlatformPreviewAndOverridePane(
                    platform: platform,
                    model: model,
                    onOpenGridPreview: { showingGridPreview = true }
                )
                // Fresh view identity per platform so override state from one
                // platform's tab never leaks into another's.
                .id(platform)
            }
        }
        .background(DayframeColor.background)
    }

    private func navBar(model: ComposerViewModel) -> some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textSecondary)
                .accessibilityLabel("Cancel composing")

            Spacer()

            HStack(spacing: DayframeSpacing.md) {
                // Secondary draft save shortcut
                if model.publishingAction != .draft {
                    Button("Draft") {
                        Task {
                            if await model.save(asDraft: true) {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .font(DayframeFont.chip)
                    .foregroundStyle(DayframeColor.textSecondary)
                    .disabled(model.isSaving)
                }

                // Dynamic Primary Submit Button
                Button {
                    Task {
                        if await model.submit() {
                            onSaved()
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if model.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: model.publishingAction.systemImage)
                            Text(primaryButtonTitle(model: model))
                        }
                    }
                    .font(DayframeFont.chip)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DayframeSpacing.md)
                    .padding(.vertical, DayframeSpacing.sm)
                    .background(DayframeColor.brandGradient)
                    .clipShape(Capsule())
                }
                .disabled(model.isSaving)
            }
        }
        .padding(.horizontal, DayframeSpacing.lg)
        .padding(.vertical, DayframeSpacing.md)
    }

    private func primaryButtonTitle(model: ComposerViewModel) -> String {
        if model.isSaving { return "Saving…" }
        if model.editingPost != nil { return "Update" }
        return model.publishingAction.rawValue
    }

    private func composePane(model: ComposerViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DayframeSpacing.lg) {
                if let error = model.validationError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color("Danger"))
                        .accessibilityLabel("Error: \(error)")
                }

                channelPicker(model: model)

                // Master Caption Editor
                VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                    HStack {
                        Text("Master Caption")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DayframeColor.textSecondary)
                        Spacer()
                        Text("Syncs to all channels")
                            .font(.system(size: 11))
                            .foregroundStyle(DayframeColor.textTertiary)
                    }

                    TextEditor(text: Binding(get: { model.bodyText }, set: { model.bodyText = $0 }))
                        .font(DayframeFont.body)
                        .foregroundStyle(DayframeColor.textPrimary)
                        .frame(minHeight: 120)
                        .focused($editorFocused)
                        .padding(DayframeSpacing.md)
                        .background(DayframeColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            HStack(spacing: DayframeSpacing.sm) {
                                ForEach(model.selectedPlatforms(), id: \.self) { platform in
                                    CharacterCounterRing(
                                        used: model.bodyFor(platform: platform).count,
                                        limit: model.limit(for: platform)
                                    )
                                }
                            }
                            .padding(DayframeSpacing.sm)
                        }
                        .accessibilityLabel("Post text")
                }

                // Built-in AI Writing Toolbar
                AIWritingToolbar(
                    currentText: model.bodyText,
                    onApplyText: { text, isReplacement in
                        applyText(text, isReplacement: isReplacement, model: model)
                    },
                    onOpenFullAssistant: { showingAISheet = true }
                )
                .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))

                // First Comment Automation Section
                firstCommentSection(model: model)

                // Media Upload Row
                mediaRow(model: model)

                // Quick Tools
                HStack(spacing: DayframeSpacing.lg) {
                    toolbarButton("face.smiling", label: "Emoji") {
                        showingEmojiSheet = true
                    }
                    toolbarButton("number", label: "Hashtag") {
                        showingHashtagSheet = true
                    }
                    toolbarButton("sparkles", label: "AI assist") {
                        showingAISheet = true
                    }
                    toolbarButton("link", label: "Link") {
                        showingLinkAlert = true
                    }
                }

                // 4 Flexible Publishing Actions
                publishingActionsSection(model: model)
            }
            .padding(DayframeSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - First Comment Automation View

    private func firstCommentSection(model: ComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    model.showsFirstCommentField.toggle()
                }
            } label: {
                HStack(spacing: DayframeSpacing.xs) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(DayframeColor.primary)
                    Text("First Comment Automation")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DayframeColor.textPrimary)

                    Spacer()

                    Text(model.showsFirstCommentField ? "Hide" : (model.firstComment.isEmpty ? "Add first comment" : "1 comment added"))
                        .font(.system(size: 12))
                        .foregroundStyle(DayframeColor.primary)

                    Image(systemName: model.showsFirstCommentField ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(DayframeColor.textSecondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if model.showsFirstCommentField {
                VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                    Text("Automatically posted right after your post goes live (supported on Instagram & LinkedIn). Ideal for links, tags, and extra CTAs!")
                        .font(.system(size: 11))
                        .foregroundStyle(DayframeColor.textSecondary)

                    TextField("Add your first comment here...", text: Binding(
                        get: { model.firstComment },
                        set: { model.firstComment = $0 }
                    ), axis: .vertical)
                    .font(DayframeFont.body)
                    .lineLimit(2...4)
                    .padding(DayframeSpacing.md)
                    .background(DayframeColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DayframeSpacing.sm)
        .background(DayframeColor.surface.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
    }

    // MARK: - 4 Publishing Actions

    private func publishingActionsSection(model: ComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            Text("Publishing Action")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DayframeSpacing.sm) {
                actionTile(
                    action: .addToQueue,
                    subtitle: model.nextQueueSlotText ?? "Next preset slot",
                    model: model
                )
                actionTile(
                    action: .schedule,
                    subtitle: "Pick exact date & time",
                    model: model
                )
                actionTile(
                    action: .draft,
                    subtitle: "Save to content bank",
                    model: model
                )
                actionTile(
                    action: .publishNow,
                    subtitle: "Dispatch right away",
                    model: model
                )
            }

            if model.publishingAction == .schedule {
                VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                    Text("Custom Publish Date & Time")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DayframeColor.textSecondary)

                    DatePicker(
                        "Publish at",
                        selection: Binding(get: { model.customDate }, set: { model.customDate = $0 }),
                        in: .now...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .tint(DayframeColor.primary)
                    .padding(DayframeSpacing.sm)
                    .background(DayframeColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                }
                .padding(.top, DayframeSpacing.xs)
            }
        }
    }

    private func actionTile(
        action: ComposerViewModel.PublishingAction,
        subtitle: String,
        model: ComposerViewModel
    ) -> some View {
        let isSelected = model.publishingAction == action
        return Button {
            model.publishingAction = action
        } label: {
            VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                HStack(spacing: 4) {
                    Image(systemName: action.systemImage)
                        .font(.system(size: 13))
                    Text(action.rawValue)
                        .font(DayframeFont.chip)
                        .fontWeight(.semibold)
                }
                Text(subtitle)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : DayframeColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DayframeSpacing.md)
            .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : AnyShapeStyle(DayframeColor.surface))
            .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func mediaRow(model: ComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
            Text("Media Assets")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DayframeColor.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DayframeSpacing.md) {
                    ForEach(model.pendingMedia) { media in
                        if let image = UIImage(data: media.data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        model.removeMedia(media)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white, DayframeColor.textSecondary)
                                    }
                                    .offset(x: 6, y: -6)
                                    .accessibilityLabel("Remove image")
                                }
                                .accessibilityLabel("Attached image")
                        }
                    }
                    PhotosPicker(
                        selection: $pickerSelection,
                        maxSelectionCount: 4,
                        matching: .images
                    ) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
                            Text("Add")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(DayframeColor.textSecondary)
                        .frame(width: 64, height: 64)
                        .background(DayframeColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                    }
                    .accessibilityLabel("Add photo")
                }
            }
        }
        .onChange(of: pickerSelection) {
            guard !pickerSelection.isEmpty else { return }
            let items = pickerSelection
            pickerSelection = []
            Task { await model.addMedia(from: items) }
        }
    }

    private func channelPicker(model: ComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
            Text("Publish to Accounts")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DayframeColor.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DayframeSpacing.md) {
                    ForEach(model.channels.filter { $0.status == .connected }) { channel in
                        let isSelected = model.selectedChannelIDs.contains(channel.id)
                        Button {
                            model.toggleChannel(channel)
                        } label: {
                            VStack(spacing: 4) {
                                ZStack(alignment: .bottomTrailing) {
                                    ChannelAvatar(platform: channel.platform, size: 40)
                                        .overlay(
                                            Circle().strokeBorder(
                                                isSelected ? DayframeColor.primary : .clear,
                                                lineWidth: 2
                                            )
                                        )

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(DayframeColor.primary)
                                            .background(Circle().fill(.white))
                                            .offset(x: 3, y: 3)
                                    }
                                }

                                Text(channel.platform.displayName)
                                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                    .foregroundStyle(isSelected ? DayframeColor.primary : DayframeColor.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .accessibilityLabel("\(isSelected ? "Deselect" : "Select") \(channel.platform.displayName)")
                    }
                }
            }
        }
        .padding(.vertical, DayframeSpacing.xs)
    }

    private func toolbarButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(DayframeColor.textSecondary)
                .frame(width: 44, height: 44)
                .background(DayframeColor.surface)
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }

    // MARK: - Helpers for Text Insertion

    private func activeText(model: ComposerViewModel) -> String {
        if case .preview(let platform) = model.selectedTab {
            return model.bodyFor(platform: platform)
        }
        return model.bodyText
    }

    private func applyText(_ text: String, isReplacement: Bool, model: ComposerViewModel) {
        if case .preview(let platform) = model.selectedTab {
            if isReplacement {
                model.setOverride(text, for: platform)
            } else {
                let current = model.bodyFor(platform: platform)
                let combined = current.isEmpty ? text : "\(current)\n\n\(text)"
                model.setOverride(combined, for: platform)
            }
        } else {
            if isReplacement {
                model.bodyText = text
            } else {
                let current = model.bodyText
                model.bodyText = current.isEmpty ? text : "\(current)\n\n\(text)"
            }
        }
    }

    private func appendSnippet(_ snippet: String, model: ComposerViewModel) {
        if case .preview(let platform) = model.selectedTab {
            let current = model.bodyFor(platform: platform)
            let combined = current.isEmpty ? snippet : "\(current) \(snippet)"
            model.setOverride(combined, for: platform)
        } else {
            let current = model.bodyText
            model.bodyText = current.isEmpty ? snippet : "\(current) \(snippet)"
        }
    }
}

/// Platform Preview pane with master-to-channel sync, per-platform custom text overrides,
/// and full-fidelity live preview cards.
struct PlatformPreviewAndOverridePane: View {
    var platform: Platform
    var model: ComposerViewModel
    var onOpenGridPreview: () -> Void

    @State private var isCustomizing = false
    @State private var overrideText = ""
    @State private var isCustomizingFirstComment = false
    @State private var overrideFirstComment = ""

    private var activeChannel: Channel? {
        model.channels.first { $0.platform == platform }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DayframeSpacing.lg) {
                // Header & Sync status indicator
                HStack(spacing: DayframeSpacing.md) {
                    ChannelAvatar(platform: platform, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: DayframeSpacing.xs) {
                            Text(platform.displayName)
                                .font(DayframeFont.headline)
                                .foregroundStyle(DayframeColor.textPrimary)

                            if model.isSyncedWithMaster(for: platform) {
                                Text("Synced with Master")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color("Success"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color("Success").opacity(0.12))
                                    .clipShape(Capsule())
                            } else {
                                Text("Customized")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(DayframeColor.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DayframeColor.primary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        Text("Character limit: \(model.limit(for: platform))")
                            .font(.system(size: 11))
                            .foregroundStyle(DayframeColor.textSecondary)
                    }
                    Spacer()

                    if platform == .instagram {
                        Button(action: onOpenGridPreview) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.grid.3x3.fill")
                                Text("Grid")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DayframeColor.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(DayframeColor.primary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, DayframeSpacing.lg)

                // Master sync toggle
                Toggle("Customize text for \(platform.displayName)", isOn: $isCustomizing)
                    .font(DayframeFont.chip)
                    .tint(DayframeColor.primary)
                    .padding(.horizontal, DayframeSpacing.lg)
                    .onChange(of: isCustomizing) { _, newValue in
                        if newValue {
                            overrideText = model.bodyOverrides[platform] ?? model.bodyText
                            model.setOverride(overrideText, for: platform)
                        } else {
                            model.clearOverride(for: platform)
                        }
                    }

                if isCustomizing {
                    VStack(alignment: .trailing, spacing: DayframeSpacing.xs) {
                        TextEditor(text: $overrideText)
                            .font(DayframeFont.body)
                            .foregroundStyle(DayframeColor.textPrimary)
                            .frame(minHeight: 100)
                            .padding(DayframeSpacing.md)
                            .background(DayframeColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous)
                                    .strokeBorder(DayframeColor.primary.opacity(0.4), lineWidth: 1)
                            )
                            .onChange(of: overrideText) { _, newText in
                                model.setOverride(newText, for: platform)
                            }

                        HStack {
                            Text("\(overrideText.count) / \(model.limit(for: platform))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(overrideText.count > model.limit(for: platform) ? Color("Danger") : DayframeColor.textSecondary)
                            CharacterCounterRing(used: overrideText.count, limit: model.limit(for: platform))
                        }
                    }
                    .padding(.horizontal, DayframeSpacing.lg)
                }

                // Per-channel first comment override if enabled
                if platform == .instagram || platform == .linkedin {
                    VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                        Toggle("Customize First Comment for \(platform.displayName)", isOn: $isCustomizingFirstComment)
                            .font(.system(size: 13))
                            .tint(DayframeColor.primary)
                            .onChange(of: isCustomizingFirstComment) { _, newValue in
                                if newValue {
                                    overrideFirstComment = model.firstCommentFor(platform: platform)
                                    model.setFirstCommentOverride(overrideFirstComment, for: platform)
                                } else {
                                    model.clearFirstCommentOverride(for: platform)
                                }
                            }

                        if isCustomizingFirstComment {
                            TextField("Custom first comment...", text: $overrideFirstComment)
                                .font(.system(size: 13))
                                .padding(DayframeSpacing.sm)
                                .background(DayframeColor.surface)
                                .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                                .onChange(of: overrideFirstComment) { _, newText in
                                    model.setFirstCommentOverride(newText, for: platform)
                                }
                        }
                    }
                    .padding(.horizontal, DayframeSpacing.lg)
                }

                // Live Platform Preview Card
                VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                    Text("LIVE PREVIEW")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DayframeColor.textSecondary)
                        .padding(.horizontal, DayframeSpacing.lg)

                    PlatformPreviewCard(
                        platform: platform,
                        bodyText: isCustomizing ? overrideText : model.bodyText,
                        firstComment: model.firstCommentFor(platform: platform),
                        media: model.pendingMedia,
                        handle: activeChannel?.handle ?? "@yourbrand",
                        displayName: activeChannel?.displayName ?? "Your Brand",
                        onOpenGridPreview: onOpenGridPreview
                    )
                    .padding(.horizontal, DayframeSpacing.lg)
                }
            }
            .padding(.vertical, DayframeSpacing.md)
        }
        .onAppear {
            if model.hasOverride(for: platform) {
                isCustomizing = true
                overrideText = model.bodyFor(platform: platform)
            }
            if model.firstCommentOverrides[platform] != nil {
                isCustomizingFirstComment = true
                overrideFirstComment = model.firstCommentFor(platform: platform)
            }
        }
    }
}

#Preview("Composer") {
    ComposerView(onSaved: {})
        .environment(AppEnvironment())
}
