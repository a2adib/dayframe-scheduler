import Foundation
import Supabase

struct LiveScheduleRepository: ScheduleRepository {
    let client: SupabaseClient

    func loadSlots() async throws -> [PostingSlot] {
        let session = try await client.auth.session
        let rows: [PostingSlotRow] = try await client
            .from("posting_slots")
            .select()
            .eq("user_id", value: session.user.id)
            .execute()
            .value
        return rows.map { row in
            PostingSlot(
                id: row.id,
                weekday: row.weekday,
                minutesFromMidnight: RowMapping.minutesFromMidnight(row.localTime),
                channelID: row.channelId,
                isActive: row.active
            )
        }
    }

    func setSlotActive(_ slot: PostingSlot, isActive: Bool) async throws {
        try await client
            .from("posting_slots")
            .update(["active": isActive])
            .eq("id", value: slot.id)
            .execute()
    }

    /// Client-side resolution of the next free slot; moves server-side with the
    /// publish-due function (TRD §4 step 6, Phase 5).
    func nextQueueSlot(after date: Date) async throws -> Date {
        let slots = try await loadSlots().filter(\.isActive)
        let calendar = Calendar.current
        for dayOffset in 0...14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let weekday = calendar.component(.weekday, from: day) - 1
            for slot in slots where slot.weekday == weekday {
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
