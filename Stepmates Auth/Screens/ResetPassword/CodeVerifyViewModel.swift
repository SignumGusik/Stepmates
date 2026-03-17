//
//  ViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 15/03/2026.
//
import Foundation

extension CodeVerifyViewController {
    final class ViewModel {
        let email: String
        let isRegistrationFlow: Bool
        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage

        init(
            email: String,
            isRegistrationFlow: Bool,
            networkHandler: NetworkHandler,
            tokenStorage: AccessTokenStorage
        ) {
            self.email = email
            self.isRegistrationFlow = isRegistrationFlow
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }
    }
}

extension CodeVerifyViewController.ViewModel {
    func resendCode() async throws {
        let route: NetworkRoutes = isRegistrationFlow ? .registerResend : .passwordResetRequest

        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }

        let body: [String: Any] = ["email": email]

        _ = try await networkHandler.request(
            url,
            jsonDictionary: body,
            httpMethod: route.method.rawValue
        )
    }

    func verifyCode(code: String) async throws {
        let route: NetworkRoutes = isRegistrationFlow ? .registerVerify : .passwordResetVerify

        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }

        let body: [String: Any] = [
            "email": email,
            "code": code
        ]

        if isRegistrationFlow {
            let response = try await networkHandler.request(
                url,
                jsonDictionary: body,
                responseType: RegisterVerifyResponseDTO.self,
                httpMethod: route.method.rawValue
            )

            let token = AccessToken(
                accessToken: response.access,
                refreshToken: response.refresh
            )

            let saveResult = tokenStorage.save(token)
            guard saveResult else {
                throw NSError(
                    domain: "AccessTokenStorage",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Не удалось сохранить токен доступа"]
                )
            }
        } else {
            _ = try await networkHandler.request(
                url,
                jsonDictionary: body,
                responseType: DetailResponseDTO.self,
                httpMethod: route.method.rawValue
            )
        }
    }
}
