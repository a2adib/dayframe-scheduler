import SwiftUI

struct QuickEmojiSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String) -> Void

    private let categories: [(name: String, emojis: [String])] = [
        ("Engagement & Growth", ["🚀", "🔥", "📈", "💡", "🎯", "⚡️", "✨", "💯", "🏆", "🌟"]),
        ("Pointers & Action", ["👇", "👉", "🧵", "📌", "✅", "👀", "📣", "🔗", "💬", "📩"]),
        ("Creator & Tech", ["📱", "💻", "🎬", "🧠", "📊", "🎨", "✍️", "☕️", "⏳", "🤝"]),
        ("Reactions & Mood", ["👏", "🎉", "🙌", "🥳", "😎", "🫡", "🙏", "❤️", "🤩", "💪"])
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DayframeSpacing.lg) {
                    ForEach(categories, id: \.name) { cat in
                        VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
                            Text(cat.name)
                                .font(DayframeFont.headline)
                                .foregroundStyle(DayframeColor.textSecondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                ForEach(cat.emojis, id: \.self) { emoji in
                                    Button {
                                        onSelect(emoji)
                                        dismiss()
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(maxWidth: .infinity, minHeight: 48)
                                            .background(DayframeColor.surface)
                                            .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(DayframeSpacing.lg)
            }
            .background(DayframeColor.background)
            .navigationTitle("Emojis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(DayframeColor.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
