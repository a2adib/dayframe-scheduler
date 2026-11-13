import Foundation

struct MockProfileRepository: ProfileRepository {
    private var profile: Profile

    init(profile: Profile = MockData.profile) {
        self.profile = profile
    }

    func loadProfile() async throws -> Profile {
        profile
    }

    func updateTheme(_ theme: Profile.Theme) async throws {
        // Mock: theme changes are not persisted.
    }

    func logout() async throws {}

    func deleteAccount() async throws {}
}
