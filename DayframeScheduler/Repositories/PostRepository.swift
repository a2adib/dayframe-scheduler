import Foundation

protocol PostRepository {
    /// Returns posts grouped for the Queue, newest scheduled day first.
    func loadQueue() async throws -> [Post]
    func loadPosts(on date: Date) async throws -> [Post]
    func loadDrafts() async throws -> [Post]
    func save(_ post: Post, as status: PostStatus, scheduleMode: ScheduleMode?, scheduledAt: Date?) async throws -> Post
    func duplicate(_ post: Post) async throws -> Post
    func delete(_ post: Post) async throws
    func reschedule(_ post: Post, to date: Date) async throws -> Post
}
