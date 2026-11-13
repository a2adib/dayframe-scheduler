import Foundation

final class MockScheduleRepository: ScheduleRepository {
    private var slots: [PostingSlot]

    init(slots: [PostingSlot] = MockData.postingSlots) {
        self.slots = slots
    }

    func loadSlots() async throws -> [PostingSlot] {
        slots
    }

    func setSlotActive(_ slot: PostingSlot, isActive: Bool) async throws {
        slots = slots.map { $0.id == slot.id ? slot : $0 }
    }

    func nextQueueSlot(after date: Date) async throws -> Date {
        let calendar = Calendar.current
        for dayOffset in 0...14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let weekday = calendar.component(.weekday, from: day) - 1
            for slot in slots where slot.isActive && slot.weekday == weekday {
                let slotTime = calendar.date(
                    bySettingHour: slot.minutesFromMidnight / 60,
                    minute: slot.minutesFromMidnight % 60,
                    second: 0,
                    of: day
                ) ?? day
                if slotTime > date {
                    return slotTime
                }
            }
        }
        return calendar.date(byAdding: .hour, value: 1, to: date) ?? date
    }
}
