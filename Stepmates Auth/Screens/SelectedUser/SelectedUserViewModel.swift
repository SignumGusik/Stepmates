//
//  SelectedUserViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 06/02/2026.
//

import Combine
import Foundation

extension SelectedUserViewController {
    class ViewModel {
        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage
        var user: AccessUsers
        
        init(networkHandler: NetworkHandler, tokenStorage: AccessTokenStorage, user: AccessUsers) {
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
            self.user = user
        }
    }
}

extension SelectedUserViewController.ViewModel {
    
    func addToFriends() async throws -> AccessFriendRequests {
        let route = NetworkRoutes.createFriendRequest
        
        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }
        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }
        let body: [String: Any] = [
            "to_user_id": user.id
        ]

        return try await networkHandler.request(
            url,
            jsonDictionary: body,
            responseType: AccessFriendRequests.self,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }
    
    func getUser() -> AccessUsers {
        
        return user
    }
    func updateUser(_ new: AccessUsers){
        self.user = new
    }
}
