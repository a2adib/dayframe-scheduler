import SwiftUI
import Charts

/// Analytics (AppFLOW 2.7, UI_Spec §4.7): range control (7d / 30d / 90d-Pro),
/// stat cards with trends, reach line chart, posts-per-channel bar chart, and
/// top posts. No Figma frame; UI_Spec defaults with Swift Charts.
struct AnalyticsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: AnalyticsViewModel?

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
        .navigationTitle("Analytics")
        .task {
            if model == nil {
                let viewModel = AnalyticsViewModel(
                    analyticsRepository: environment.analyticsRepository,
                    channelRepository: environment.channelRepository
                )
                model = viewModel
                await viewModel.load()
            }
        }
    }

    private func content(model: AnalyticsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DayframeSpacing.lg) {
                rangeControl(model: model)
                channelFilter(model: model)

                let totals = model.totals
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DayframeSpacing.md) {
                    StatCard(value: formatCount(totals.followers), label: "Followers", trend: .up, trendDelta: "+3%")
                    StatCard(value: formatCount(totals.reach), label: "Reach", trend: .up, trendDelta: "+8%")
                    StatCard(value: formatCount(totals.engagement), label: "Engagement", trend: .down, trendDelta: "-1%")
                    StatCard(value: formatCount(totals.clicks), label: "Clicks", trend: .none)
                }

                reachChart(model: model)
                postsPerChannelChart(model: model)
                topPosts(model: model)
            }
            .padding(DayframeSpacing.lg)
        }
        .refreshable { await model.load() }
        .sheet(isPresented: Binding(
            get: { model.showsProPrompt },
            set: { model.showsProPrompt = $0 }
        )) {
            upgradeSheet(model: model)
        }
    }

    private func rangeControl(model: AnalyticsViewModel) -> some View {
        Picker("Range", selection: Binding(
            get: { model.rangeDays },
            set: { newValue in
                if newValue == 90 {
                    model.showsProPrompt = true
                } else {
                    model.rangeDays = newValue
                    Task { await model.load() }
                }
            }
        )) {
            Text("7d").tag(7)
            Text("30d").tag(30)
            Text("90d").tag(90)
        }
        .pickerStyle(.segmented)
        .tint(DayframeColor.primary)
        .accessibilityLabel("Date range")
    }

    private func channelFilter(model: AnalyticsViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DayframeSpacing.sm) {
                chip("All", isSelected: model.selectedPlatform == nil) { model.selectedPlatform = nil }
                ForEach(model.channels, id: \.id) { channel in
                    chip(
                        channel.platform.displayName,
                        isSelected: model.selectedPlatform == channel.platform
                    ) {
                        model.selectedPlatform = channel.platform
                    }
                }
            }
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DayframeFont.chip)
                .foregroundStyle(isSelected ? .white : DayframeColor.textSecondary)
                .padding(.horizontal, DayframeSpacing.md)
                .padding(.vertical, DayframeSpacing.sm)
                .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : AnyShapeStyle(DayframeColor.surface))
                .clipShape(Capsule())
        }
        .accessibilityLabel("Filter \(title)")
    }

    private func reachChart(model: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            Text("Reach")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)
            Chart(model.reachSeries, id: \.day) { point in
                AreaMark(
                    x: .value("Day", point.day),
                    y: .value("Reach", point.reach)
                )
                .foregroundStyle(DayframeColor.brandGradient.opacity(0.2))
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Reach", point.reach)
                )
                .foregroundStyle(DayframeColor.primary)
                .interpolationMethod(.catmullRom)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
            .accessibilityLabel("Reach over the last \(model.rangeDays) days")
        }
        .padding(DayframeSpacing.lg)
        .background(DayframeColor.background)
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
    }

    private func postsPerChannelChart(model: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            Text("Posts per channel")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)
            Chart(model.postsPerChannel, id: \.platform) { item in
                BarMark(
                    x: .value("Posts", item.count),
                    y: .value("Channel", item.platform.displayName)
                )
                .foregroundStyle(DayframeColor.brandGradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .frame(height: CGFloat(model.postsPerChannel.count) * 40 + 20)
            .accessibilityLabel("Scheduled posts per channel")
        }
        .padding(DayframeSpacing.lg)
        .background(DayframeColor.background)
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
    }

    private func topPosts(model: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            Text("Top posts")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)
            ForEach(model.topPosts) { post in
                HStack(spacing: DayframeSpacing.md) {
                    ChannelAvatar(platform: post.platform, size: 36)
                    Text(post.body)
                        .font(.system(size: 13))
                        .foregroundStyle(DayframeColor.textPrimary)
                        .lineLimit(2)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCount(post.reach))
                            .font(DayframeFont.chip)
                            .foregroundStyle(DayframeColor.textPrimary)
                        Text("reach")
                            .font(.system(size: 11))
                            .foregroundStyle(DayframeColor.textSecondary)
                    }
                }
                .padding(DayframeSpacing.md)
                .background(DayframeColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
            }
            if model.topPosts.isEmpty {
                Text("Data appears here after your first published posts.")
                    .font(DayframeFont.chip)
                    .foregroundStyle(DayframeColor.textSecondary)
            }
        }
    }

    private func upgradeSheet(model: AnalyticsViewModel) -> some View {
        VStack(spacing: DayframeSpacing.lg) {
            DayframeLogoMark(size: 56)
            Text("Analytics Pro")
                .font(DayframeFont.largeTitle(24))
                .foregroundStyle(DayframeColor.textPrimary)
            Text("Unlock 90-day ranges, unlimited channels, and unlimited scheduled posts.")
                .font(DayframeFont.body)
                .foregroundStyle(DayframeColor.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Upgrade to Pro", systemImage: "crown") {
                model.showsProPrompt = false
            }
            SecondaryButton(title: "Restore purchases") {
                model.showsProPrompt = false
            }
        }
        .padding(DayframeSpacing.xl)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func formatCount(_ value: Int) -> String {
        value >= 1000 ? String(format: "%.1fk", Double(value) / 1000) : String(value)
    }
}

#Preview("Analytics") {
    NavigationStack {
        AnalyticsView()
    }
    .environment(AppEnvironment())
}

#Preview("Analytics dark") {
    NavigationStack {
        AnalyticsView()
    }
    .environment(AppEnvironment())
    .environment(\.colorScheme, .dark)
}
