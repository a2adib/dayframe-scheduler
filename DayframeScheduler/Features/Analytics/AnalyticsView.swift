import SwiftUI
import Charts

/// Actionable Analytics & Posting Streaks:
/// - Consistency Streaks goal-tracking widget (Weekly goal & streak weeks)
/// - Cross-channel & per-channel metrics (Reach, Engagement Rate, Clicks, Followers)
/// - Date-range filters (7d / 30d / 90d-Pro)
/// - 1-Click "Re-Queue / Repurpose" to duplicate top-performing posts directly into Composer
struct AnalyticsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: AnalyticsViewModel?
    @State private var postToRepurpose: Post?

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
        .fullScreenCover(item: $postToRepurpose) { post in
            ComposerView(editingPost: post, onSaved: {
                postToRepurpose = nil
                Task { await model?.load() }
            })
        }
    }

    private func content(model: AnalyticsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DayframeSpacing.lg) {
                // Consistency Streaks Widget
                consistencyStreakWidget(model: model)

                rangeControl(model: model)
                channelFilter(model: model)

                // 4 Core Stat Cards
                let totals = model.totals
                let followerTrend = model.trend(for: \.followers)
                let reachTrend = model.trend(for: \.reach)
                let engagementTrend = model.trend(for: \.engagement)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DayframeSpacing.md) {
                    StatCard(value: formatCount(totals.reach), label: "Impressions & Reach", trend: reachTrend.direction, trendDelta: reachTrend.delta)
                    StatCard(value: model.engagementRateText, label: "Engagement Rate", trend: engagementTrend.direction, trendDelta: engagementTrend.delta)
                    StatCard(value: formatCount(totals.clicks), label: "Link Clicks", trend: .none)
                    StatCard(value: formatCount(totals.followers), label: "Followers", trend: followerTrend.direction, trendDelta: followerTrend.delta)
                }

                reachChart(model: model)
                postsPerChannelChart(model: model)

                // Top Posts with 1-Click "Re-Queue / Repurpose"
                topPostsSection(model: model)
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

    // MARK: - Consistency Streaks Widget

    private func consistencyStreakWidget(model: AnalyticsViewModel) -> some View {
        let streak = model.streakInfo
        return VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
            HStack {
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.system(size: 20))
                    Text("\(streak.streakWeeks)-Week Streak")
                        .font(DayframeFont.headline)
                        .foregroundStyle(DayframeColor.textPrimary)
                }

                Spacer()

                Text("\(streak.publishedThisWeek)/\(streak.weeklyGoal) posts this week")
                    .font(DayframeFont.chip)
                    .foregroundStyle(DayframeColor.primary)
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DayframeColor.border)
                        .frame(height: 8)

                    Capsule()
                        .fill(DayframeColor.brandGradient)
                        .frame(width: geo.size.width * streak.progressFraction, height: 8)
                }
            }
            .frame(height: 8)

            // 7 Days Dot Indicator (M, T, W, T, F, S, S)
            HStack {
                ForEach(streak.days) { day in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(day.isCompleted ? Color("Success") : DayframeColor.border)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: day.isCompleted ? "checkmark" : "")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        Text(day.dayLetter)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(day.isCompleted ? DayframeColor.textPrimary : DayframeColor.textTertiary)
                    }
                    if day.id != streak.days.last?.id {
                        Spacer()
                    }
                }
            }
            .padding(.top, 4)

            Text("You're on track! Post 1 more time to hit your weekly consistency goal.")
                .font(.system(size: 12))
                .foregroundStyle(DayframeColor.textSecondary)
                .padding(.top, 2)
        }
        .padding(DayframeSpacing.md)
        .background(DayframeColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
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
            Text("Reach Over Time")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)

            let series = model.reachSeries
            if series.isEmpty {
                Text("No reach data for this range.")
                    .font(DayframeFont.chip)
                    .foregroundStyle(DayframeColor.textSecondary)
                    .frame(height: 160)
            } else {
                Chart(series, id: \.day) { point in
                    LineMark(
                        x: .value("Day", point.day, unit: .day),
                        y: .value("Reach", point.reach)
                    )
                    .foregroundStyle(DayframeColor.brandGradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", point.day, unit: .day),
                        y: .value("Reach", point.reach)
                    )
                    .foregroundStyle(DayframeColor.primary.opacity(0.12))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, model.rangeDays / 5))) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.day()))
                                    .font(DayframeFont.caption)
                                    .foregroundStyle(DayframeColor.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        if let count = value.as(Int.self) {
                            AxisValueLabel {
                                Text(formatCount(count))
                                    .font(DayframeFont.caption)
                                    .foregroundStyle(DayframeColor.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(DayframeSpacing.md)
        .background(DayframeColor.background)
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
    }

    private func postsPerChannelChart(model: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            Text("Posts Published")
                .font(DayframeFont.headline)
                .foregroundStyle(DayframeColor.textPrimary)

            let data = model.postsPerChannel
            if data.isEmpty {
                Text("No posts published in this range.")
                    .font(DayframeFont.chip)
                    .foregroundStyle(DayframeColor.textSecondary)
                    .frame(height: 120)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Posts", item.count),
                        y: .value("Channel", item.platform.displayName)
                    )
                    .foregroundStyle(DayframeColor.primary)
                    .cornerRadius(4)
                }
                .frame(height: CGFloat(max(data.count * 36, 100)))
            }
        }
        .padding(DayframeSpacing.md)
        .background(DayframeColor.background)
        .overlay(
            RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous)
                .strokeBorder(DayframeColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
    }

    // MARK: - Top Posts & 1-Click "Re-Queue / Repurpose"

    private func topPostsSection(model: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.md) {
            HStack {
                Text("Top Performing Posts")
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.textPrimary)
                Spacer()
                Text("Highest reach")
                    .font(DayframeFont.caption)
                    .foregroundStyle(DayframeColor.textSecondary)
            }

            ForEach(model.topPosts) { post in
                VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
                    HStack(spacing: DayframeSpacing.md) {
                        ChannelAvatar(platform: post.platform, size: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.body)
                                .font(.system(size: 13))
                                .foregroundStyle(DayframeColor.textPrimary)
                                .lineLimit(2)

                            HStack(spacing: 8) {
                                Text("\(formatCount(post.reach)) reach")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DayframeColor.primary)
                                Text("•")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DayframeColor.textTertiary)
                                Text("High Engagement")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color("Success"))
                            }
                        }

                        Spacer()

                        // 1-Click "Re-Queue / Repurpose" Button
                        Button {
                            postToRepurpose = model.makeRepurposePost(from: post)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.2.squarepath")
                                    .font(.system(size: 11))
                                Text("Re-Queue")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(DayframeColor.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(DayframeColor.primary.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Re-Queue post: \(post.body.prefix(30))")
                    }
                }
                .padding(DayframeSpacing.md)
                .background(DayframeColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.card, style: .continuous))
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
