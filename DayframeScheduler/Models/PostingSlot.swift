import Foundation

struct PostingSlot: Identifiable, Equatable {
    var id: UUID
    /// 0 = Sunday … 6 = Saturday (Schema.md `posting_slots.weekday`).
    var weekday: Int
    /// Local time-of-day in minutes since midnight.
    var minutesFromMidnight: Int
    var channelID: UUID?
    var isActive: Bool

    var timeText: String {
        let hour = (minutesFromMidnight / 60) % 24
        let minute = minutesFromMidnight % 60
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}
