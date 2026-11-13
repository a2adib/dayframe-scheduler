import Foundation

protocol ScheduleRepository {
    func loadSlots() async throws -> [PostingSlot]
    func setSlotActive(_ slot: PostingSlot, isActive: Bool) async throws
    /// Next free queue slot from the active posting slots (server-side in TRD §4).
    func nextQueueSlot(after date: Date) async throws -> Date
}
