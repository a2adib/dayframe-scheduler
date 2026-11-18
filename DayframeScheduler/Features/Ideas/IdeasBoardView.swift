import SwiftUI

/// Ideas Board (Kanban Content Bank):
/// - Pipeline stages: Raw Ideas → Drafting → Ready to Schedule
/// - 1-Click "Convert to Post" pre-populating Post Composer
/// - Idea capture with notes, tags, and inspiration links
struct IdeasBoardView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: IdeasBoardViewModel?
    @State private var showingNewIdeaSheet = false
    @State private var ideaToConvert: Idea?
    @State private var ideaToEdit: Idea?

    var body: some View {
        Group {
            if let model {
                content(model: model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DayframeColor.background)
        .navigationTitle("Ideas Board")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewIdeaSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New Idea")
                    }
                    .font(DayframeFont.chip)
                    .fontWeight(.semibold)
                    .foregroundStyle(DayframeColor.primary)
                }
            }
        }
        .task {
            if model == nil {
                let viewModel = IdeasBoardViewModel(ideaRepository: environment.ideaRepository)
                model = viewModel
                await viewModel.load()
            }
        }
        .fullScreenCover(item: $ideaToConvert) { idea in
            ComposerView(prefillIdea: idea, onSaved: {
                ideaToConvert = nil
                Task {
                    await model?.moveToStage(idea: idea, to: .ready)
                    await model?.load()
                }
            })
        }
        .sheet(isPresented: $showingNewIdeaSheet) {
            if let model {
                NewIdeaSheet(model: model)
            }
        }
    }

    private func content(model: IdeasBoardViewModel) -> some View {
        VStack(spacing: 0) {
            // Stage Picker (Kanban Columns)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DayframeSpacing.sm) {
                    ForEach([IdeaStage.raw, .drafting, .ready], id: \.self) { stage in
                        let isSelected = model.selectedStage == stage
                        let count = model.count(for: stage)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                model.selectedStage = stage
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: stage.systemImage)
                                Text(stage.displayName)
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? .white.opacity(0.25) : DayframeColor.border)
                                    .clipShape(Capsule())
                            }
                            .font(DayframeFont.chip)
                            .foregroundStyle(isSelected ? .white : DayframeColor.textSecondary)
                            .padding(.horizontal, DayframeSpacing.md)
                            .padding(.vertical, DayframeSpacing.sm)
                            .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : AnyShapeStyle(DayframeColor.surface))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DayframeSpacing.lg)
                .padding(.vertical, DayframeSpacing.sm)
            }
            .background(DayframeColor.background)

            Divider()

            // Cards Feed
            if model.filteredIdeas.isEmpty {
                emptyStageView(model: model)
            } else {
                ScrollView {
                    LazyVStack(spacing: DayframeSpacing.md) {
                        ForEach(model.filteredIdeas) { idea in
                            ideaCard(idea: idea, model: model)
                        }
                    }
                    .padding(DayframeSpacing.lg)
                }
                .refreshable {
                    await model.load()
                }
            }
        }
    }

    private func ideaCard(idea: Idea, model: IdeasBoardViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
            HStack(alignment: .top) {
                Text(idea.title)
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.textPrimary)
                    .lineLimit(2)

                Spacer()

                Menu {
                    Button("Convert to Post", systemImage: "paperplane") {
                        ideaToConvert = idea
                    }
                    Divider()
                    Menu("Move to Stage") {
                        ForEach(IdeaStage.allCases) { stage in
                            Button(stage.displayName) {
                                Task { await model.moveToStage(idea: idea, to: stage) }
                            }
                        }
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        Task { await model.deleteIdea(idea) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(DayframeColor.textSecondary)
                        .frame(width: 28, height: 28)
                }
            }

            if !idea.notes.isEmpty {
                Text(idea.notes)
                    .font(DayframeFont.body)
                    .foregroundStyle(DayframeColor.textSecondary)
                    .lineLimit(3)
            }

            if let link = idea.link, !link.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                    Text(link)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                .foregroundStyle(DayframeColor.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DayframeColor.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            // Tags
            if !idea.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(idea.tags, id: \.self) { tag in
                        Text(tag.hasPrefix("#") ? tag : "#\(tag)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DayframeColor.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DayframeColor.surface)
                            .clipShape(Capsule())
                    }
                }
            }

            Divider()
                .padding(.top, 4)

            // Bottom Actions: Convert to Post + Advance Stage
            HStack {
                // 1-Click Convert to Post Button
                Button {
                    ideaToConvert = idea
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11))
                        Text("Convert to Post")
                            .font(DayframeFont.chip)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DayframeSpacing.md)
                    .padding(.vertical, 6)
                    .background(DayframeColor.brandGradient)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                // Stage Progression Pill
                if idea.stage != .ready {
                    Button {
                        Task { await model.advanceStage(for: idea) }
                    } label: {
                        HStack(spacing: 4) {
                            Text(advanceLabel(for: idea.stage))
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(DayframeColor.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(DayframeColor.surface)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DayframeSpacing.md)
        .background(DayframeColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
    }

    private func advanceLabel(for stage: IdeaStage) -> String {
        switch stage {
        case .raw: return "To Drafting"
        case .drafting: return "To Ready"
        case .ready: return "Done"
        case .converted: return ""
        }
    }

    private func emptyStageView(model: IdeasBoardViewModel) -> some View {
        VStack(spacing: DayframeSpacing.md) {
            Image(systemName: model.selectedStage.systemImage)
                .font(.system(size: 44))
                .foregroundStyle(DayframeColor.primary.opacity(0.5))

            Text("No \(model.selectedStage.displayName) yet")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)

            Text("Capture spontaneous thoughts, references, and outlines in your content bank.")
                .font(.system(size: 13))
                .foregroundStyle(DayframeColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DayframeSpacing.xl)

            Button {
                showingNewIdeaSheet = true
            } label: {
                Text("+ Capture New Idea")
                    .font(DayframeFont.chip)
                    .fontWeight(.semibold)
                    .foregroundStyle(DayframeColor.primary)
                    .padding(.horizontal, DayframeSpacing.lg)
                    .padding(.vertical, DayframeSpacing.sm)
                    .background(DayframeColor.primary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.top, DayframeSpacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - New Idea Quick Capture Sheet

struct NewIdeaSheet: View {
    @Environment(\.dismiss) private var dismiss
    var model: IdeasBoardViewModel

    @State private var title = ""
    @State private var notes = ""
    @State private var stage: IdeaStage = .raw
    @State private var link = ""
    @State private var tagsText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Core Idea") {
                    TextField("What's the core hook or topic?", text: $title)
                        .font(DayframeFont.headline)

                    TextField("Rough notes, outline, or key bullet points...", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Pipeline Stage") {
                    Picker("Stage", selection: $stage) {
                        Text("Raw Idea").tag(IdeaStage.raw)
                        Text("Drafting").tag(IdeaStage.drafting)
                        Text("Ready to Schedule").tag(IdeaStage.ready)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Metadata & Assets") {
                    TextField("Tags (comma separated, e.g. ai, growth)", text: $tagsText)

                    TextField("Link (optional inspiration URL)", text: $link)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("New Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Idea") {
                        let parsedTags = tagsText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }

                        Task {
                            await model.addIdea(
                                title: title.isEmpty ? "Untitled Idea" : title,
                                notes: notes,
                                stage: stage,
                                tags: parsedTags,
                                link: link.isEmpty ? nil : link
                            )
                            dismiss()
                        }
                    }
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.primary)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty && notes.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("IdeasBoard") {
    NavigationStack {
        IdeasBoardView()
            .environment(AppEnvironment())
    }
}
