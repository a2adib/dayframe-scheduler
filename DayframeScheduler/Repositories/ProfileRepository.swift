import Foundation

protocol ProfileRepository {
    func loadProfile() async throws -> Profile
    func updateTheme(_ theme: Profile.Theme) async throws
    func logout() async throws
    func deleteAccount() async throws
}
