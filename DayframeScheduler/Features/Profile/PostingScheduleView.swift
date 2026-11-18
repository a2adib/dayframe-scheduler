import SwiftUI

/// Posting schedule editor (AppFLOW 2.8, UI_Spec §4.8): weekly preset time slots
/// per channel or all channels, with toggles and slot creation.
struct PostingScheduleView: View {
    var model: ProfileViewModel

    @State private var showingAddSlot = false
    @State private var newWeekday = 1 // Monday default
    @State private var newTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    @State private var selectedChannelID: UUID? = nil

    private let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private var activeCount: Int {
        model.slots.filter(\.isActive).count
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: DayframeSpacing.md) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundStyle(DayframeColor.brandGradient)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(activeCount) Active Weekly Slots")
                            .font(DayframeFont.headline)
                            .foregroundStyle(DayframeColor.textPrimary)
                        Text("When you choose 'Add to Queue', posts automatically fill your next available preset slot in your local timezone.")
                            .font(.system(size: 12))
                            .foregroundStyle(DayframeColor.textSecondary)
                    }
                }
                .padding(.vertical, DayframeSpacing.xs)
                .listRowBackground(DayframeColor.surface)
            }

            ForEach(0...6, id: \.self) { weekday in
                let weekdaySlots = model.slots.filter { $0.weekday == weekday }
                Section(weekdayNames[weekday]) {
                    if weekdaySlots.isEmpty {
                        Text("No scheduled slots")
                            .font(.system(size: 13))
                            .foregroundStyle(DayframeColor.textTertiary)
                            .listRowBackground(DayframeColor.background)
                    } else {
                        ForEach(weekdaySlots) { slot in
                            TimeSlotRow(
                                title: slot.timeText,
                                subtitle: channelLabel(for: slot),
                                isActive: Binding(
                                    get: { slot.isActive },
                                    set: { newValue in
                                        Task { await model.toggleSlot(slot, isActive: newValue) }
                                    }
                                )
                            )
                            .listRowBackground(DayframeColor.background)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await model.deleteSlot(slot) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Posting Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSlot = true
                } label: {
                    Label("Add Slot", systemImage: "plus")
                        .font(DayframeFont.headline)
                        .foregroundStyle(DayframeColor.primary)
                }
            }
        }
        .sheet(isPresented: $showingAddSlot) {
            addSlotSheet
        }
    }

    private func channelLabel(for slot: PostingSlot) -> String {
        if let id = slot.channelID, let channel = model.channels.first(where: { $0.id == id }) {
            return "\(channel.platform.displayName) (\(channel.handle))"
        }
        return "All connected channels"
    }

    private var addSlotSheet: some View {
        NavigationStack {
            Form {
                Section("Day & Time") {
                    Picker("Weekday", selection: $newWeekday) {
                        ForEach(0...6, id: \.self) { day in
                            Text(weekdayNames[day]).tag(day)
                        }
                    }

                    DatePicker("Time", selection: $newTime, displayedComponents: .hourAndMinute)
                }

                Section("Channel Assignment") {
                    Picker("Applies To", selection: $selectedChannelID) {
                        Text("All Channels").tag(nil as UUID?)
                        ForEach(model.channels) { ch in
                            Text("\(ch.platform.displayName) (\(ch.handle))").tag(ch.id as UUID?)
                        }
                    }
                }
            }
            .navigationTitle("Add Time Slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddSlot = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await model.addSlot(weekday: newWeekday, time: newTime, channelID: selectedChannelID)
                            showingAddSlot = false
                        }
                    }
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("PostingSchedule") {
    NavigationStack {
        PostingScheduleView(model: ProfileViewModel(
            profileRepository: MockProfileRepository(),
            channelRepository: MockChannelRepository(),
            scheduleRepository: MockScheduleRepository()
        ))
    }
}
