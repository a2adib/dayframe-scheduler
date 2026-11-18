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
            .order("weekday", ascending: true)
            .order("local_time", ascending: true)
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

    func addSlot(weekday: Int, minutesFromMidnight: Int, channelID: UUID?) async throws -> PostingSlot {
        let session = try await client.auth.session
        let hour = (minutesFromMidnight / 60) % 24
        let minute = minutesFromMidnight % 60
        let timeStr = String(format: "%02d:%02d:00", hour, minute)

        struct InsertSlotRow: Codable {
            var userId: UUID
            var weekday: Int
            var localTime: String
            var channelId: UUID?
            var active: Bool
        }

        let payload = InsertSlotRow(
            userId: session.user.id,
            weekday: weekday,
            localTime: timeStr,
            channelId: channelID,
            active: true
        )

        let inserted: PostingSlotRow = try await client
            .from("posting_slots")
            .insert(payload, returning: .representation)
            .single()
            .execute()
            .value

        return PostingSlot(
            id: inserted.id,
            weekday: inserted.weekday,
            minutesFromMidnight: minutesFromMidnight,
            channelID: inserted.channelId,
            isActive: inserted.active
        )
    }

    func deleteSlot(_ slot: PostingSlot) async throws {
        try await client
            .from("posting_slots")
            .delete()
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
