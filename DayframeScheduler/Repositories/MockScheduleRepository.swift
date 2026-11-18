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
        slots = slots.map { $0.id == slot.id ? PostingSlot(id: $0.id, weekday: $0.weekday, minutesFromMidnight: $0.minutesFromMidnight, channelID: $0.channelID, isActive: isActive) : $0 }
    }

    func addSlot(weekday: Int, minutesFromMidnight: Int, channelID: UUID?) async throws -> PostingSlot {
        let newSlot = PostingSlot(
            id: UUID(),
            weekday: weekday,
            minutesFromMidnight: minutesFromMidnight,
            channelID: channelID,
            isActive: true
        )
        slots.append(newSlot)
        return newSlot
    }

    func deleteSlot(_ slot: PostingSlot) async throws {
        slots.removeAll { $0.id == slot.id }
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
