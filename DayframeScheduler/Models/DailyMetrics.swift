import Foundation

struct DailyMetrics: Identifiable, Equatable {
    var id: UUID { UUID(uuidString: "\(channelID.uuidString)-\(day.timeIntervalSince1970)") ?? UUID() }
    var channelID: UUID
    var day: Date
    var followers: Int
    var reach: Int
    var engagement: Int
    var clicks: Int
}

struct TopPost: Identifiable, Equatable {
    var id: UUID
    var body: String
    var platform: Platform
    var reach: Int
    var engagement: Int
}
