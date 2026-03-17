//
//  SearchFriendsViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 02/02/2026.
//

import Foundation

extension SearchFriendsViewController {
    class ViewModel {
        private let networkHandler: NetworkHandler
        private let friendsService: FriendsService
        private let tokenStorage: AccessTokenStorage
        
        init(networkHandler: NetworkHandler, friendsService: FriendsService, tokenStorage: AccessTokenStorage) {
            self.networkHandler = networkHandler
            self.friendsService = friendsService
            self.tokenStorage = tokenStorage
        }
    }
}

extension SearchFriendsViewController.ViewModel {
    func getSearchFriends(query: String?) async -> [AccessUsers] {
        let text = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if text.isEmpty {
            return []
        }
        
        do {
            return try await friendsService.searchFriends(query: text)
        } catch {
            print("search friends error: \(error)")
            return []
        }
    }
    
    func addToFriends(_ user: AccessUsers) async throws -> AccessFriendRequests {
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
}
