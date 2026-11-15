import SwiftUI

struct AISuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let content: String
    let subtitle: String?
}

struct AIAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss
    var currentText: String
    var onApply: (String, Bool) -> Void // (text, isReplacement)

    @State private var isGenerating = false
    @State private var suggestions: [AISuggestion] = []
    @State private var selectedAction: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DayframeSpacing.lg) {
                    headerSection

                    actionButtonsGrid

                    if isGenerating {
                        VStack(spacing: DayframeSpacing.md) {
                            ProgressView()
                                .tint(DayframeColor.primary)
                            Text("Generating suggestions…")
                                .font(DayframeFont.caption)
                                .foregroundStyle(DayframeColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DayframeSpacing.xl)
                    } else if !suggestions.isEmpty {
                        suggestionsList
                    }
                }
                .padding(DayframeSpacing.lg)
            }
            .background(DayframeColor.background)
            .navigationTitle("AI Assist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(DayframeColor.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerSection: some View {
        HStack(spacing: DayframeSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(DayframeColor.brandGradient)
            VStack(alignment: .leading, spacing: 2) {
                Text("Supercharge Your Post")
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.textPrimary)
                Text("Choose an action to craft viral hooks, adapt for platforms, or polish phrasing.")
                    .font(.system(size: 13))
                    .foregroundStyle(DayframeColor.textSecondary)
            }
        }
        .padding(DayframeSpacing.md)
        .background(DayframeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
    }

    private var actionButtonsGrid: some View {
        VStack(spacing: DayframeSpacing.sm) {
            HStack(spacing: DayframeSpacing.sm) {
                actionPill("💡 3 Viral Hooks", actionKey: "hooks") {
                    generateHooks()
                }
                actionPill("⚡️ Punchy for X", actionKey: "x_format") {
                    formatForX()
                }
            }
            HStack(spacing: DayframeSpacing.sm) {
                actionPill("👔 LinkedIn Story", actionKey: "linkedin_format") {
                    formatForLinkedIn()
                }
                actionPill("✨ Polish Tone", actionKey: "polish") {
                    polishTone()
                }
            }
            actionPill("🏷️ Generate 5 Niche Hashtags", actionKey: "hashtags") {
                generateHashtags()
            }
        }
    }

    private func actionPill(_ title: String, actionKey: String, action: @escaping () -> Void) -> some View {
        let isSelected = selectedAction == actionKey
        return Button(action: {
            selectedAction = actionKey
            action()
        }) {
            Text(title)
                .font(DayframeFont.chip)
                .foregroundStyle(isSelected ? .white : DayframeColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DayframeSpacing.sm + 2)
                .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : AnyShapeStyle(DayframeColor.surface))
                .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
        }
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            Text("Suggestions")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)

            ForEach(suggestions) { item in
                VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
                    HStack {
                        Text(item.title)
                            .font(DayframeFont.chip)
                            .foregroundStyle(DayframeColor.primary)
                        Spacer()
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(DayframeColor.textSecondary)
                        }
                    }

                    Text(item.content)
                        .font(DayframeFont.body)
                        .foregroundStyle(DayframeColor.textPrimary)
                        .padding(DayframeSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DayframeColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))

                    HStack(spacing: DayframeSpacing.md) {
                        Button("Replace post") {
                            onApply(item.content, true)
                            dismiss()
                        }
                        .font(DayframeFont.chip)
                        .foregroundStyle(DayframeColor.primary)

                        Spacer()

                        Button("Append to post") {
                            onApply(item.content, false)
                            dismiss()
                        }
                        .font(DayframeFont.chip)
                        .foregroundStyle(DayframeColor.textSecondary)
                    }
                    .padding(.top, 2)
                }
                .padding(DayframeSpacing.md)
                .background(DayframeColor.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                        .strokeBorder(DayframeColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
            }
        }
    }

    // MARK: - Generation Logic

    private func cleanBase() -> String {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sharing an exciting update with you all today." : trimmed
    }

    private func generateHooks() {
        isGenerating = true
        let base = cleanBase()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            suggestions = [
                AISuggestion(
                    title: "Curiosity Hook",
                    content: "Most people overlook this simple fact about \(base.prefix(40))… Here's the breakdown:",
                    subtitle: "High Engagement"
                ),
                AISuggestion(
                    title: "Contrarian Hook",
                    content: "Stop doing \(base.prefix(35)) the old way. Here is why the game changed:",
                    subtitle: "Discussion Driver"
                ),
                AISuggestion(
                    title: "Story Hook",
                    content: "I didn't expect this to work, but here is what happened with \(base.prefix(30)):",
                    subtitle: "Personal Brand"
                )
            ]
            isGenerating = false
        }
    }

    private func formatForX() {
        isGenerating = true
        let base = cleanBase()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let short = String(base.prefix(220))
            suggestions = [
                AISuggestion(
                    title: "Punchy Tweet",
                    content: "\(short)\n\nThoughts? 👇 #buildinpublic",
                    subtitle: "\(min(280, short.count + 35)) chars"
                )
            ]
            isGenerating = false
        }
    }

    private func formatForLinkedIn() {
        isGenerating = true
        let base = cleanBase()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            suggestions = [
                AISuggestion(
                    title: "Structured Story",
                    content: "Here is a key lesson from this week:\n\n\(base)\n\nThree takeaways:\n1. Start small and iterate rapidly.\n2. Consistency beats intensity.\n3. Focus on delivering genuine value.\n\nWhat has been your experience with this? Would love to hear your insights.",
                    subtitle: "LinkedIn Optimized"
                )
            ]
            isGenerating = false
        }
    }

    private func polishTone() {
        isGenerating = true
        let base = cleanBase()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            suggestions = [
                AISuggestion(
                    title: "Polished & Clear",
                    content: "\(base)\n\nExcited to hear what everyone thinks!",
                    subtitle: "Smooth Flow"
                )
            ]
            isGenerating = false
        }
    }

    private func generateHashtags() {
        isGenerating = true
        let base = cleanBase().lowercased()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var tags = ["#growth", "#creator", "#socialmedia", "#productivity", "#buildinpublic"]
            if base.contains("ios") || base.contains("swift") || base.contains("app") {
                tags = ["#swiftui", "#iosdev", "#indiehacker", "#mobiledev", "#apple"]
            } else if base.contains("design") || base.contains("ui") {
                tags = ["#uidesign", "#uxdesign", "#productdesign", "#creatives", "#figma"]
            }
            suggestions = [
                AISuggestion(
                    title: "Recommended Hashtags",
                    content: tags.joined(separator: " "),
                    subtitle: "5 Tags"
                )
            ]
            isGenerating = false
        }
    }
}
