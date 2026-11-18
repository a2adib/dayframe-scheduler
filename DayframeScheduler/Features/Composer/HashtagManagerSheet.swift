import SwiftUI

struct HashtagBundle: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var tags: [String]

    var formattedString: String {
        tags.map { $0.hasPrefix("#") ? $0 : "#\($0)" }.joined(separator: " ")
    }
}

struct HashtagManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onInsert: (String) -> Void

    @State private var customTagInput = ""
    @State private var customBundleName = ""
    @State private var showingAddCustom = false

    @State private var bundles: [HashtagBundle] = [
        HashtagBundle(
            name: "Tech & Indie Dev",
            tags: ["#buildinpublic", "#swiftui", "#iosdev", "#indiehacker", "#developer"]
        ),
        HashtagBundle(
            name: "Design & UX",
            tags: ["#design", "#uiux", "#creators", "#mobileapp", "#minimalism"]
        ),
        HashtagBundle(
            name: "Growth & Creator",
            tags: ["#contentcreator", "#socialmediamarketing", "#growthmindset", "#solopreneur"]
        ),
        HashtagBundle(
            name: "SaaS & Productivity",
            tags: ["#saas", "#productivity", "#worksmart", "#remotework", "#buildfast"]
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(bundles) { bundle in
                        VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                            HStack {
                                Text(bundle.name)
                                    .font(DayframeFont.headline)
                                    .foregroundStyle(DayframeColor.textPrimary)
                                Spacer()
                                Button("Insert") {
                                    onInsert(bundle.formattedString)
                                    dismiss()
                                }
                                .font(DayframeFont.chip)
                                .foregroundStyle(DayframeColor.primary)
                                .buttonStyle(.bordered)
                                .tint(DayframeColor.primary)
                            }
                            Text(bundle.formattedString)
                                .font(.system(size: 13))
                                .foregroundStyle(DayframeColor.textSecondary)
                        }
                        .padding(.vertical, DayframeSpacing.xs)
                    }
                } header: {
                    Text("Saved Collections")
                }

                Section("Add Custom Collection") {
                    VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
                        TextField("Collection name (e.g. Weekly Roundup)", text: $customBundleName)
                            .font(DayframeFont.body)
                        TextField("Hashtags (e.g. #apple #iphone #tech)", text: $customTagInput)
                            .font(DayframeFont.body)

                        Button("Save & Insert") {
                            saveAndInsert()
                        }
                        .font(DayframeFont.chip)
                        .foregroundStyle(DayframeColor.primary)
                        .disabled(customBundleName.isEmpty || customTagInput.isEmpty)
                    }
                    .padding(.vertical, DayframeSpacing.xs)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Hashtags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DayframeColor.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func saveAndInsert() {
        let tags = customTagInput
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }

        let newBundle = HashtagBundle(name: customBundleName, tags: tags)
        bundles.append(newBundle)
        onInsert(newBundle.formattedString)
        dismiss()
    }
}
