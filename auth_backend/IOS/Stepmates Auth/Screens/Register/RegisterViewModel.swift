//
//  RegisterViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 27/01/2026.
//

import Foundation

extension RegisterViewController {
    class ViewModel {
        var email: String?
        var password: String?
        var confirmPassword: String?
        
        private let networkHandler: NetworkHandler
        
        init(networkHandler: NetworkHandler) {
            self.networkHandler = networkHandler
        }
        
    }
}
 // MARK: - Actions
extension RegisterViewController.ViewModel {
    
    func submitRegister() async throws {
        guard let email, let password, let confirmPassword else {
            throw FormError.missingFields
        }
        
        guard !email.isEmpty,
              !password.isEmpty,
              !confirmPassword.isEmpty,
              password == confirmPassword else {
            print("Email and password required")
            throw FormError.incorrectEntries
        }
        
        let route = NetworkRoutes.register
        let method = route.method
        guard let url = route.url else {
            print("No URL found")
            throw ConfigurationError.nilObject
        }
        let jsonDictionary = [
            "email": email,
            "password": password,
            "password2": confirmPassword
        ]
        _ = try await networkHandler.request(
            url,
            jsonDictionary: jsonDictionary,
            httpMethod: method.rawValue
        )
    }
    
}
