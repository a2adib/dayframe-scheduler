import SwiftUI

/// Built-in AI Writing Toolbar embedded inside the Composer (AppFLOW 2.3).
/// Provides 1-tap inline AI actions:
/// 1. Rewrite for Platform Tone (LinkedIn, X, Instagram, Threads, TikTok)
/// 2. Generate Scroll-Stopping Hooks
/// 3. Shorten / Expand
/// 4. Auto-Suggest Hashtags
struct AIWritingToolbar: View {
    var currentText: String
    var onApplyText: (String, Bool) -> Void // (text, isReplacement)
    var onOpenFullAssistant: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DayframeSpacing.sm) {
                // Open Full Assistant Button
                Button(action: onOpenFullAssistant) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(DayframeColor.brandGradient)
                        Text("AI Tools")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DayframeColor.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DayframeColor.primary.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // 1. Rewrite for Platform Tone Menu
                Menu {
                    Button("LinkedIn (Professional Story)") {
                        rewriteForTone(platform: .linkedin)
                    }
                    Button("X / Twitter (Punchy & Direct)") {
                        rewriteForTone(platform: .x)
                    }
                    Button("Instagram (Engaging & Visual)") {
                        rewriteForTone(platform: .instagram)
                    }
                    Button("Threads (Conversational & Authentic)") {
                        rewriteForTone(platform: .threads)
                    }
                    Button("TikTok (High-Energy Hook)") {
                        rewriteForTone(platform: .tiktok)
                    }
                } label: {
                    aiChip(title: "Rewrite Tone", icon: "slider.horizontal.3")
                }

                // 2. Generate Scroll-Stopping Hooks
                Menu {
                    Button("Curiosity Gap Hook") {
                        applyHook(type: .curiosity)
                    }
                    Button("Bold Contrarian Hook") {
                        applyHook(type: .contrarian)
                    }
                    Button("Story & Vulnerability Hook") {
                        applyHook(type: .story)
                    }
                    Button("Numbered Listicle Hook") {
                        applyHook(type: .listicle)
                    }
                } label: {
                    aiChip(title: "Viral Hooks", icon: "bolt.fill")
                }

                // 3. Shorten / Expand Menu
                Menu {
                    Button("Shorten (Cut fluff / punchy)") {
                        shortenText()
                    }
                    Button("Expand (Add depth & context)") {
                        expandText()
                    }
                } label: {
                    aiChip(title: "Shorten / Expand", icon: "arrow.left.and.right")
                }

                // 4. Auto-Suggest Hashtags
                Button {
                    suggestHashtags()
                } label: {
                    aiChip(title: "Auto-Hashtags", icon: "number")
                }
            }
            .padding(.horizontal, DayframeSpacing.md)
            .padding(.vertical, 4)
        }
        .background(DayframeColor.surface.opacity(0.6))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func aiChip(title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(DayframeColor.primary)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DayframeColor.textPrimary)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(DayframeColor.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DayframeColor.background)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
    }

    // MARK: - AI Action Logic

    private func cleanText() -> String {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sharing exciting updates on our newest project today!" : trimmed
    }

    private func rewriteForTone(platform: Platform) {
        let base = cleanText()
        let result: String
        switch platform {
        case .linkedin:
            result = "Key learning from building this week:\n\n\(base)\n\n3 key takeaways:\n1. Execution beats planning every time\n2. Systems create consistency\n3. Feedback loops accelerate momentum\n\nWhat are you focused on building this quarter?"
        case .x:
            result = "\(base.prefix(180))\n\nQuick thought: the simplest systems always scale the farthest. 🚀"
        case .instagram:
            result = "Behind the scenes snapshot ✨\n\n\(base)\n\nDrop a 🔥 below if you want the full behind the scenes breakdown!"
        case .facebook:
            result = "Excited to share an update with you all today! 🌟\n\n\(base)\n\nLet me know your thoughts in the comments below!"
        case .threads:
            result = "Honest thought of the day:\n\n\(base)\n\nAgree or disagree? Would love to hear everyone's perspective."
        case .tiktok, .youtube:
            result = "POV: You finally cracked the routine.\n\n\(base)\n\nFollow for daily breakdowns! 🎬"
        }
        onApplyText(result, true)
    }

    enum HookType {
        case curiosity, contrarian, story, listicle
    }

    private func applyHook(type: HookType) {
        let base = cleanText()
        let hook: String
        switch type {
        case .curiosity:
            hook = "Most people overlook this simple rule:\n\n\(base)"
        case .contrarian:
            hook = "Unpopular opinion: the standard advice is completely backwards.\n\n\(base)"
        case .story:
            hook = "6 months ago I made a mistake that changed how I work forever:\n\n\(base)"
        case .listicle:
            hook = "5 principles that changed everything for me:\n\n\(base)"
        }
        onApplyText(hook, true)
    }

    private func shortenText() {
        let base = cleanText()
        let sentences = base.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if let first = sentences.first {
            let shortened = "\(first.trimmingCharacters(in: .whitespaces)). Straight to the point."
            onApplyText(shortened, true)
        } else {
            onApplyText(base.prefix(120) + "…", true)
        }
    }

    private func expandText() {
        let base = cleanText()
        let expanded = "\(base)\n\nHere is why this matters right now:\n• Reduces friction and mental fatigue\n• Keeps output predictable and sustainable\n• Allows you to focus on high-impact creative decisions\n\nLet me know your thoughts!"
        onApplyText(expanded, true)
    }

    private func suggestHashtags() {
        let base = cleanText().lowercased()
        var tags: [String] = []

        if base.contains("build") || base.contains("code") || base.contains("app") || base.contains("ios") {
            tags.append(contentsOf: ["#buildinpublic", "#indiedev", "#iosdev", "#swiftui", "#tech"])
        } else if base.contains("design") || base.contains("creative") || base.contains("ui") {
            tags.append(contentsOf: ["#designsystem", "#uidesign", "#creativelife", "#visualdesign", "#minimalism"])
        } else if base.contains("grow") || base.contains("market") || base.contains("audience") || base.contains("brand") {
            tags.append(contentsOf: ["#contentstrategy", "#creatorgrowth", "#marketingtips", "#personalbranding", "#growthaudience"])
        } else {
            tags.append(contentsOf: ["#creatoreconomy", "#productivity", "#mindset", "#dailyhabits", "#consistency"])
        }

        let tagString = "\n\n" + tags.joined(separator: " ")
        onApplyText(tagString, false)
    }
}
