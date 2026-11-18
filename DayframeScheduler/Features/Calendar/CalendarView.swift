import SwiftUI

/// Visual Content Calendar (AppFLOW 2.6, UI_Spec §4.5):
/// - Weekly and monthly calendar views showing post thumbnails and platform badges
/// - Interactive rescheduling across dates with 1-tap or drag action
/// - Direct channel filtering across calendar schedules
struct CalendarView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: CalendarViewModel?
    @State private var monthAnchor = Date.now
    @State private var showsDayList = false
    @State private var selectedPost: Post?
    @State private var postToReschedule: Post?
    @State private var rescheduleTargetDate = Date.now
    @State private var showsComposer = false

    var body: some View {
        Group {
            if let model {
                calendar(model: model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DayframeColor.background)
        .navigationTitle("Calendar")
        .task {
            if model == nil {
                let viewModel = CalendarViewModel(
                    postRepository: environment.postRepository,
                    channelRepository: environment.channelRepository
                )
                model = viewModel
                await viewModel.load()
            }
        }
    }

    private func calendar(model: CalendarViewModel) -> some View {
        VStack(spacing: DayframeSpacing.md) {
            // View Mode Toggle (Month vs Week)
            HStack {
                Picker("View", selection: Binding(
                    get: { model.showsWeek },
                    set: { model.showsWeek = $0 }
                )) {
                    Text("Month").tag(false)
                    Text("Week").tag(true)
                }
                .pickerStyle(.segmented)
                .tint(DayframeColor.primary)
            }
            .padding(.horizontal, DayframeSpacing.lg)

            // Platform Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DayframeSpacing.sm) {
                    filterChip("All", isSelected: model.selectedPlatform == nil) {
                        model.selectedPlatform = nil
                    }
                    ForEach(model.channels, id: \.id) { channel in
                        filterChip(channel.platform.displayName, isSelected: model.selectedPlatform == channel.platform) {
                            model.selectedPlatform = channel.platform
                        }
                    }
                }
                .padding(.horizontal, DayframeSpacing.lg)
            }

            if model.showsWeek {
                WeekStrip(model: model, onTapDay: { day in
                    model.selectedDate = day
                    showsDayList = true
                })
            } else {
                MonthGrid(
                    monthAnchor: $monthAnchor,
                    model: model,
                    onTapDay: { day in
                        model.selectedDate = day
                        showsDayList = true
                    }
                )
            }

            Spacer()
        }
        .padding(.top, DayframeSpacing.md)
        .sheet(isPresented: $showsDayList) {
            dayList(model: model)
        }
        .sheet(item: $selectedPost) { post in
            NavigationStack {
                PostDetailView(
                    post: post,
                    platforms: model.platforms(for: post),
                    onDeleted: {
                        selectedPost = nil
                        Task { await model.load() }
                    },
                    onRescheduled: { _ in
                        selectedPost = nil
                        Task { await model.load() }
                    }
                )
            }
        }
        .sheet(item: $postToReschedule) { post in
            rescheduleSheet(for: post, model: model)
        }
        .fullScreenCover(isPresented: $showsComposer) {
            ComposerView(presetDate: model.selectedDate, onSaved: {
                showsComposer = false
                Task { await model.load() }
            })
        }
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DayframeFont.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? .white : DayframeColor.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : AnyShapeStyle(DayframeColor.surface))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func dayList(model: CalendarViewModel) -> some View {
        let date = model.selectedDate ?? .now
        let posts = model.posts(on: date)
        return VStack(alignment: .leading, spacing: DayframeSpacing.lg) {
            SectionHeader(
                title: date.formatted(.dateTime.weekday(.wide).month().day()),
                trailingText: "\(posts.count) post\(posts.count == 1 ? "" : "s")"
            )
            if posts.isEmpty {
                EmptyStateView(
                    title: "Nothing scheduled",
                    message: "No posts scheduled for this day yet.",
                    actionTitle: "Schedule for this day",
                    action: {
                        showsDayList = false
                        showsComposer = true
                    }
                )
            } else {
                ScrollView {
                    VStack(spacing: DayframeSpacing.md) {
                        ForEach(posts) { post in
                            VStack(alignment: .trailing, spacing: 6) {
                                Button {
                                    showsDayList = false
                                    selectedPost = post
                                } label: {
                                    PostCard(
                                        platforms: model.platforms(for: post),
                                        timeText: post.scheduledAt?.formatted(.dateTime.hour().minute()) ?? "",
                                        status: post.status,
                                        bodyText: post.body,
                                        mediaCaption: post.media.first?.kind == .image ? "Photo attached" : nil,
                                        hasFirstComment: post.firstComment != nil && !post.firstComment!.isEmpty
                                    )
                                }
                                .buttonStyle(.plain)

                                HStack {
                                    Button {
                                        postToReschedule = post
                                        rescheduleTargetDate = post.scheduledAt ?? date
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar.badge.clock")
                                            Text("Reschedule")
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(DayframeColor.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(DayframeColor.primary.opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(DayframeSpacing.lg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func rescheduleSheet(for post: Post, model: CalendarViewModel) -> some View {
        NavigationStack {
            Form {
                Section("Pick New Date & Time") {
                    DatePicker("Scheduled At", selection: $rescheduleTargetDate, in: .now..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                }
            }
            .navigationTitle("Reschedule Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { postToReschedule = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        Task {
                            await model.reschedule(post: post, to: rescheduleTargetDate)
                            postToReschedule = nil
                        }
                    }
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.primary)
                }
            }
        }
        .presentationDetents([.large])
    }
}

/// Month grid with post thumbnail dots and platform icons.
private struct MonthGrid: View {
    @Binding var monthAnchor: Date
    var model: CalendarViewModel
    var onTapDay: (Date) -> Void

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        let calendar = Calendar.current
        let days = gridDays()
        return VStack(spacing: DayframeSpacing.sm) {
            HStack {
                Button {
                    monthAnchor = calendar.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .foregroundStyle(DayframeColor.textSecondary)
                }
                .accessibilityLabel("Previous month")
                Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.textPrimary)
                Spacer()
                Button {
                    monthAnchor = calendar.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                        .foregroundStyle(DayframeColor.textSecondary)
                }
                .accessibilityLabel("Next month")
            }
            .padding(.horizontal, DayframeSpacing.md)

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(DayframeFont.caption)
                        .foregroundStyle(DayframeColor.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DayframeSpacing.xs), count: 7), spacing: DayframeSpacing.sm) {
                ForEach(days, id: \.self) { day in
                    dayCell(day, calendar: calendar)
                }
            }
            .padding(.horizontal, DayframeSpacing.md)
        }
    }

    private func gridDays() -> [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for dayOffset in 0..<daysInMonth {
            cells.append(calendar.date(byAdding: .day, value: dayOffset, to: monthInterval.start))
        }
        return cells
    }

    private func dayCell(_ day: Date?, calendar: Calendar) -> some View {
        Group {
            if let day {
                let isToday = calendar.isDateInToday(day)
                let isSelected = model.selectedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                let dayPosts = model.posts(on: day)
                Button {
                    onTapDay(day)
                } label: {
                    VStack(spacing: 3) {
                        Text(String(calendar.component(.day, from: day)))
                            .font(DayframeFont.chip)
                            .foregroundStyle(isSelected ? .white : DayframeColor.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : isToday ? AnyShapeStyle(DayframeColor.surface) : AnyShapeStyle(.clear))
                            .clipShape(Circle())

                        if !dayPosts.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(dayPosts.prefix(2)) { post in
                                    if let platform = model.platforms(for: post).first {
                                        PlatformBadge(platform: platform, size: 8)
                                    }
                                }
                            }
                            .frame(height: 8)
                        } else {
                            Circle().fill(Color.clear).frame(height: 8)
                        }
                    }
                }
                .accessibilityLabel("\(day.formatted(.dateTime.month().day())), \(dayPosts.count) posts")
            } else {
                Color.clear.frame(height: 42)
            }
        }
    }
}

/// Week view: one horizontal strip of the current week's days with post preview cards.
private struct WeekStrip: View {
    var model: CalendarViewModel
    var onTapDay: (Date) -> Void

    var body: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return VStack(spacing: DayframeSpacing.md) {
            HStack(spacing: DayframeSpacing.sm) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = calendar.date(byAdding: .day, value: offset, to: start) ?? .now
                    let isSelected = model.selectedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                    let posts = model.posts(on: day)
                    Button {
                        onTapDay(day)
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(DayframeFont.caption)
                                .foregroundStyle(DayframeColor.textTertiary)
                            Text(String(calendar.component(.day, from: day)))
                                .font(DayframeFont.chip)
                                .foregroundStyle(isSelected ? .white : DayframeColor.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : AnyShapeStyle(DayframeColor.surface))
                                .clipShape(Circle())

                            if !posts.isEmpty {
                                HStack(spacing: 2) {
                                    ForEach(posts.prefix(2)) { post in
                                        if let platform = model.platforms(for: post).first {
                                            PlatformBadge(platform: platform, size: 9)
                                        }
                                    }
                                }
                            } else {
                                Color.clear.frame(height: 9)
                            }
                        }
                        .padding(DayframeSpacing.xs)
                    }
                    .accessibilityLabel("\(day.formatted(.dateTime.month().day())), \(posts.count) posts")
                }
            }
            .padding(.horizontal, DayframeSpacing.md)
        }
    }
}

#Preview("Calendar") {
    NavigationStack {
        CalendarView()
    }
    .environment(AppEnvironment())
}
