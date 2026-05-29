import Foundation
import Testing
@testable import Stepmates_Auth

struct Stepmates_AuthTests {
    @Test func appModuleExposesCoreRoutes() async throws {
        #expect(normalizedPath(NetworkRoutes.accessToken.url) == "/api/auth/token")
        #expect(NetworkRoutes.myTodaySteps.method == .get)
    }

    private func normalizedPath(_ url: URL?) -> String? {
        guard let path = url?.path else { return nil }
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "/" + trimmed
    }
}
