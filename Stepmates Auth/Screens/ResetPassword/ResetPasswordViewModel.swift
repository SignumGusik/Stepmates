import Foundation

extension ResetPasswordViewController {
    final class ViewModel {
        var email: String?

        private let networkHandler: NetworkHandler

        init(networkHandler: NetworkHandler) {
            self.networkHandler = networkHandler
        }
    }
}

// MARK: - Actions
extension ResetPasswordViewController.ViewModel {
    func submitReset() async throws {
        print("⏳ submitReset started for email: \(email ?? "nil")")
        guard let email else { throw FormError.missingFields }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { throw FormError.missingFields }

        let route = NetworkRoutes.passwordResetRequest
        guard let url = route.url else { throw ConfigurationError.nilObject }

        let body: [String: Any] = [
            "email": trimmed
        ]

        _ = try await networkHandler.request(
            url,
            jsonDictionary: body,
            httpMethod: route.method.rawValue
        )
    }
}

// MARK: - Local errors
enum ResetPasswordError: LocalizedError {
    case emailNotFound

    var errorDescription: String? {
        switch self {
        case .emailNotFound:
            return "Аккаунт с такой почтой не найден"
        }
    }
}

