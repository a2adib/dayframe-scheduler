import SwiftUI

/// Calendar (AppFLOW 2.6, UI_Spec §4.5): month grid with post dots, week
/// toggle, and a day-post list in a bottom sheet. No Figma frame; UI_Spec
/// defaults.
struct CalendarView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: CalendarViewModel?
    @State private var monthAnchor = Date.now
    @State private var showsDayList = false
    @State private var selectedPost: Post?
    @State private var showsComposer = false

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

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
                let viewModel = CalendarViewModel(postRepository: environment.postRepository)
                model = viewModel
                await viewModel.load()
            }
        }
    }

    private func calendar(model: CalendarViewModel) -> some View {
        VStack(spacing: DayframeSpacing.md) {
            Picker("View", selection: Binding(
                get: { model.showsWeek },
                set: { model.showsWeek = $0 }
            )) {
                Text("Month").tag(false)
                Text("Week").tag(true)
            }
            .pickerStyle(.segmented)
            .tint(DayframeColor.primary)
            .padding(.horizontal, DayframeSpacing.lg)

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
        .fullScreenCover(isPresented: $showsComposer) {
            ComposerView(onSaved: { showsComposer = false })
        }
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
                    title: "Nothing planned",
                    message: "Nothing planned. Frame your day.",
                    actionTitle: "Create post",
                    action: { showsComposer = true }
                )
            } else {
                ForEach(posts) { post in
                    Button {
                        selectedPost = post
                        showsDayList = false
                    } label: {
                        PostCard(
                            platforms: [.instagram],
                            timeText: post.scheduledAt?.formatted(.dateTime.hour().minute()) ?? "",
                            status: post.status,
                            bodyText: post.body,
                            mediaCaption: post.media.first?.kind == .image ? "Image attached" : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(DayframeSpacing.lg)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

/// Month grid with dots on days that have posts.
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
                Button {
                    onTapDay(day)
                } label: {
                    VStack(spacing: DayframeSpacing.xs) {
                        Text(String(calendar.component(.day, from: day)))
                            .font(DayframeFont.chip)
                            .foregroundStyle(isSelected ? .white : DayframeColor.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : isToday ? AnyShapeStyle(DayframeColor.surface) : AnyShapeStyle(.clear))
                            .clipShape(Circle())
                        Circle()
                            .fill(model.posts(on: day).isEmpty ? .clear : DayframeColor.primary)
                            .frame(width: 5, height: 5)
                    }
                }
                .accessibilityLabel("\(day.formatted(.dateTime.month().day())), \(model.posts(on: day).count) posts")
            } else {
                Color.clear.frame(height: 38)
            }
        }
    }
}

/// Week view: one horizontal strip of the current week's days.
private struct WeekStrip: View {
    var model: CalendarViewModel
    var onTapDay: (Date) -> Void

    var body: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return HStack(spacing: DayframeSpacing.sm) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: start) ?? .now
                let isSelected = model.selectedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                Button {
                    onTapDay(day)
                } label: {
                    VStack(spacing: DayframeSpacing.xs) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(DayframeFont.caption)
                            .foregroundStyle(DayframeColor.textTertiary)
                        Text(String(calendar.component(.day, from: day)))
                            .font(DayframeFont.chip)
                            .foregroundStyle(isSelected ? .white : DayframeColor.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(isSelected ? AnyShapeStyle(DayframeColor.primary) : AnyShapeStyle(DayframeColor.surface))
                            .clipShape(Circle())
                        Circle()
                            .fill(model.posts(on: day).isEmpty ? .clear : DayframeColor.primary)
                            .frame(width: 5, height: 5)
                    }
                    .padding(DayframeSpacing.xs)
                }
                .accessibilityLabel("\(day.formatted(.dateTime.month().day())), \(model.posts(on: day).count) posts")
            }
        }
        .padding(.horizontal, DayframeSpacing.md)
    }
}

#Preview("Calendar") {
    NavigationStack {
        CalendarView()
    }
    .environment(AppEnvironment())
}

#Preview("Calendar dark") {
    NavigationStack {
        CalendarView()
    }
    .environment(AppEnvironment())
    .environment(\.colorScheme, .dark)
}
