//
//  LoginViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 27/01/2026.
//

import Foundation

enum LoginError: LocalizedError {
    case missingFields
    case invalidCredentials
    case userNotFound
    case inactiveAccount
    case networkUnavailable
    case serverUnavailable
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingFields:
            return "Введите почту и пароль."
        case .invalidCredentials:
            return "Почта или пароль не подходят. Проверьте данные и попробуйте ещё раз."
        case .userNotFound:
            return "Аккаунт с такой почтой не найден."
        case .inactiveAccount:
            return "Аккаунт ещё не активирован. Проверьте письмо с кодом на почте."
        case .networkUnavailable:
            return "Не получается подключиться к серверу. Проверьте интернет и попробуйте ещё раз."
        case .serverUnavailable:
            return "Сервер ответил неожиданно. Попробуйте ещё раз чуть позже."
        case .serverMessage(let message):
            return message
        }
    }
}

extension LoginViewController {
    class ViewModel {
        var email: String?
        var password: String?
        
        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage
        
        init(networkHandler: NetworkHandler, tokenStorage: AccessTokenStorage) {
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }
    }
}


// MARK: - ACTIONS

extension LoginViewController.ViewModel {
    
    func submitLogin() async throws {
        guard let email, let password else {
            throw LoginError.missingFields
        }
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            print("Email and password required")
            throw LoginError.missingFields
        }
        
        let route = NetworkRoutes.accessToken
        let method = route.method
        guard let url = route.url else {
            print("No Url found")
            throw ConfigurationError.nilObject
        }
        let jsonDictionary = [
            "email": trimmedEmail,
            "password": password
        ]
        
        do {
            let accessToken =  try await networkHandler.request(
                url,
                jsonDictionary: jsonDictionary,
                responseType: AccessToken.self,
                httpMethod: method.rawValue
            )
            tokenStorage.save(accessToken)
        } catch {
            throw makeLoginError(from: error)
        }
    }
}

private extension LoginViewController.ViewModel {
    func makeLoginError(from error: Error) -> LoginError {
        if let loginError = error as? LoginError {
            return loginError
        }

        if error is URLError {
            return .networkUnavailable
        }

        if case let NetworkError.failedStatusCodeResponseData(statusCode, data) = error {
            if let message = extractServerMessage(from: data) {
                return mapServerMessage(message)
            }

            if statusCode == 400 || statusCode == 401 {
                return .invalidCredentials
            }

            return .serverUnavailable
        }

        if error is DecodingError {
            return .serverUnavailable
        }

        return .serverMessage(error.localizedDescription)
    }

    func mapServerMessage(_ message: String) -> LoginError {
        let normalized = message.lowercased()

        if normalized.contains("пользователь не найден") {
            return .userNotFound
        }

        if normalized.contains("аккаунт не активирован") {
            return .inactiveAccount
        }

        if normalized.contains("неверный пароль") {
            return .invalidCredentials
        }

        if normalized.contains("email") && normalized.contains("пароль") {
            return .missingFields
        }

        return .serverMessage(message)
    }

    func extractServerMessage(from data: Data) -> String? {
        guard data.isEmpty == false,
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        return collectMessages(from: object)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.isEmpty == false }
    }

    func collectMessages(from object: Any) -> [String] {
        if let string = object as? String {
            return [string]
        }

        if let array = object as? [Any] {
            return array.flatMap { element -> [String] in
                collectMessages(from: element)
            }
        }

        if let dictionary = object as? [String: Any] {
            let preferredKeys: [String] = [
                "detail",
                "non_field_errors",
                "email",
                "password",
                "error"
            ]

            let otherKeys: [String] = dictionary.keys
                .filter { key in
                    preferredKeys.contains(key) == false
                }
                .sorted()

            let orderedKeys: [String] = preferredKeys + otherKeys

            return orderedKeys.flatMap { key -> [String] in
                guard let value = dictionary[key] else {
                    return []
                }

                return collectMessages(from: value)
            }
        }

        return []
    }
}
