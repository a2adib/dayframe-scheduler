import SwiftUI

/// Posting schedule editor (AppFLOW 2.8): weekly time slots, per channel or
/// all, with toggles.
struct PostingScheduleView: View {
    var model: ProfileViewModel

    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        List {
            ForEach(1...5, id: \.self) { weekday in
                Section(weekdayNames[weekday]) {
                    ForEach(model.slots.filter { $0.weekday == weekday }) { slot in
                        TimeSlotRow(
                            title: slot.timeText,
                            subtitle: slot.channelID == nil ? "All channels" : "One channel",
                            isActive: Binding(
                                get: { slot.isActive },
                                set: { newValue in
                                    Task { await model.toggleSlot(slot, isActive: newValue) }
                                }
                            )
                        )
                        .listRowBackground(DayframeColor.background)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Posting Schedule")
        .navigationBarTitleDisplayMode(.inline)
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
