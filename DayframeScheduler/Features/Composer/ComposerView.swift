import PhotosUI
import SwiftUI
import UIKit

/// Composer full-screen sheet (AppFLOW 2.3, UI_Spec §4.4): channel
/// multi-select with counter rings, text editor, media row, toolbar, schedule
/// options, and per-platform preview tab. No Figma frame; UI_Spec defaults.
struct ComposerView: View {
    var onSaved: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: ComposerViewModel?
    @State private var pickerSelection: [PhotosPickerItem] = []
    @FocusState private var editorFocused: Bool

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
                    scheduleRepository: environment.scheduleRepository
                )
                model = viewModel
                await viewModel.load()
            }
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
                        Text(platform.displayName).tag(ComposerViewModel.Tab.preview(platform))
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DayframeSpacing.lg)
            .padding(.vertical, DayframeSpacing.md)
            .tint(DayframeColor.primary)

            if case .compose = model.selectedTab {
                composePane(model: model)
            } else if case .preview(let platform) = model.selectedTab {
                PreviewPane(platform: platform, bodyText: model.bodyText)
                Spacer()
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
                Button("Save draft") {
                    Task { if await model.save(asDraft: true) { onSaved() } }
                }
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)
                .disabled(model.isSaving)
                .accessibilityLabel("Save draft")
                PrimaryButton(title: model.isSaving ? "Saving…" : "Schedule") {
                    Task { if await model.save(asDraft: false) { onSaved() } }
                }
                .frame(width: 120)
            }
        }
        .padding(.horizontal, DayframeSpacing.lg)
        .padding(.vertical, DayframeSpacing.md)
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
                                CharacterCounterRing(used: model.bodyText.count, limit: model.limit(for: platform))
                            }
                        }
                        .padding(DayframeSpacing.sm)
                    }
                    .accessibilityLabel("Post text")

                mediaRow(model: model)

                HStack(spacing: DayframeSpacing.lg) {
                    toolbarButton("face.smiling", label: "Emoji")
                    toolbarButton("number", label: "Hashtag")
                    toolbarButton("sparkles", label: "AI assist")
                    toolbarButton("link", label: "Link")
                }

                scheduleOptions(model: model)
            }
            .padding(DayframeSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func mediaRow(model: ComposerViewModel) -> some View {
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
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 18))
                        .foregroundStyle(DayframeColor.textSecondary)
                        .frame(width: 64, height: 64)
                        .background(DayframeColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                }
                .accessibilityLabel("Add photo")
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
        HStack(spacing: DayframeSpacing.md) {
            ForEach(model.channels.filter { $0.status == .connected }) { channel in
                let isSelected = model.selectedChannelIDs.contains(channel.id)
                Button {
                    model.toggleChannel(channel)
                } label: {
                    ChannelAvatar(platform: channel.platform, size: 40)
                        .overlay(
                            Circle().strokeBorder(
                                isSelected ? DayframeColor.primary : .clear,
                                lineWidth: 2
                            )
                        )
                        .overlay(alignment: .topTrailing) {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DayframeColor.primary)
                                    .background(Circle().fill(.white))
                            }
                        }
                }
                .accessibilityLabel("\(isSelected ? "Deselect" : "Select") \(channel.platform.displayName)")
            }
            Spacer()
        }
        .padding(.vertical, DayframeSpacing.xs)
    }

    private func toolbarButton(_ systemImage: String, label: String) -> some View {
        Button {
            editorFocused = true
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(DayframeColor.textSecondary)
                .frame(width: 44, height: 44)
                .background(DayframeColor.surface)
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }

    private func scheduleOptions(model: ComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            Text("Schedule")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)

            HStack(spacing: DayframeSpacing.sm) {
                modeOption("Add to queue", subtitle: model.nextQueueSlotText ?? "Next free slot", mode: .queue, model: model)
                modeOption("Custom", subtitle: "Pick a date & time", mode: .custom, model: model)
                modeOption("Now", subtitle: "Post immediately", mode: .now, model: model)
            }

            if model.scheduleMode == .custom {
                DatePicker(
                    "Publish at",
                    selection: Binding(get: { model.customDate }, set: { model.customDate = $0 }),
                    in: .now...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .tint(DayframeColor.primary)
                .accessibilityLabel("Custom publish date")
            }
        }
    }

    private func modeOption(_ title: String, subtitle: String, mode: ScheduleMode, model: ComposerViewModel) -> some View {
        let isSelected = model.scheduleMode == mode
        return Button {
            model.scheduleMode = mode
        } label: {
            VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                Text(title)
                    .font(DayframeFont.chip)
                Text(subtitle)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : DayframeColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DayframeSpacing.md)
            .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : AnyShapeStyle(DayframeColor.surface))
            .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
        }
        .accessibilityLabel("\(title): \(subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Static per-platform preview of the composed text (AppFLOW 2.3 step 6).
struct PreviewPane: View {
    var platform: Platform
    var bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            HStack(spacing: DayframeSpacing.md) {
                ChannelAvatar(platform: platform, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dayframe")
                        .font(DayframeFont.chip)
                        .foregroundStyle(DayframeColor.textPrimary)
                    Text("just now")
                        .font(.system(size: 12))
                        .foregroundStyle(DayframeColor.textSecondary)
                }
            }
            Text(bodyText.isEmpty ? "Nothing written yet." : bodyText)
                .font(DayframeFont.body)
                .foregroundStyle(DayframeColor.textPrimary)
            Spacer()
        }
        .padding(DayframeSpacing.lg)
        .background(DayframeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        .padding(DayframeSpacing.lg)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Composer") {
    ComposerView(onSaved: {})
        .environment(AppEnvironment())
}

#Preview("PreviewPane") {
    PreviewPane(platform: .instagram, bodyText: "Studio refresh tour drops Friday. 🎬")
        .background(DayframeColor.background)
}
