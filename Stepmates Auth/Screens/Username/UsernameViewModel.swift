//
//  UsernameViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 17/03/2026.
//

import Foundation

extension UsernameViewController {
    final class ViewModel {
        var username: String?

        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage

        init(
            networkHandler: NetworkHandler,
            tokenStorage: AccessTokenStorage
        ) {
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }
    }
}

// MARK: - Models
struct UsernameRequest: Codable {
    let username: String

    var jsonDictionary: [String: Any] {
        [
            "username": username
        ]
    }
}

struct UsernameResponse: Codable {
    let detail: String
    let username: String
}

// MARK: - Actions
extension UsernameViewController.ViewModel {
    func submitUsername() async throws -> UsernameResponse {
        guard let username else { throw UsernameError.missingFields }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.isEmpty == false else { throw UsernameError.missingFields }
        guard trimmed.count >= 3 else { throw UsernameError.tooShort }
        guard trimmed.count <= 30 else { throw UsernameError.tooLong }
        guard trimmed.range(of: "^[A-Za-z0-9_]+$", options: .regularExpression) != nil else {
            throw UsernameError.invalidFormat
        }

        guard let accessToken = tokenStorage.get() else {
            throw UsernameError.missingAccessToken
        }

        let route = NetworkRoutes.setUsername
        guard let url = route.url else { throw ConfigurationError.nilObject }

        let requestModel = UsernameRequest(username: trimmed)

        return try await networkHandler.request(
            url,
            jsonDictionary: requestModel.jsonDictionary,
            responseType: UsernameResponse.self,
            httpMethod: route.method.rawValue,
            accessToken: accessToken.accessToken
        )
    }
}


