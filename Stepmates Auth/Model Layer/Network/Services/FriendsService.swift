//
//  FriendsService.swift
//  Stepmates Auth
//
//  Created by Диана on 31/01/2026.
//

import Foundation

final class FriendsService {
    private let networkHandler: NetworkHandler
    private let tokenStorage: AccessTokenStorage
    
    init(networkHandler: NetworkHandler, tokenStorage: AccessTokenStorage) {
        self.networkHandler = networkHandler
        self.tokenStorage = tokenStorage
    }
    
    func searchFriends(query: String) async throws -> [AccessUsers] {
        let route = NetworkRoutes.searchUsers(query: query)
        
        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }
        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }
        
        return try await networkHandler.request(
                    url,
                    responseType: [AccessUsers].self,
                    httpMethod: route.method.rawValue,
                    accessToken: accessToken
                )
    }
    
    func getAllFriends() async throws -> [AccessUsers] {
        let route = NetworkRoutes.friendsList
        
        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }
        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }
        
        return try await networkHandler.request(
                    url,
                    responseType: [AccessUsers].self,
                    httpMethod: route.method.rawValue,
                    accessToken: accessToken
                )
    }
    func sendFriendRequest(toUserID id: Int) async throws -> AccessFriendRequests {
        let route = NetworkRoutes.createFriendRequest
        
        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }
        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }
        
        let body: [String: Any] = [
            "to_user_id": id
        ]
        
        return try await networkHandler.request(
            url,
            jsonDictionary: body,
            responseType: AccessFriendRequests.self,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }

    func acceptFriendRequest(requestID: Int) async throws -> AccessFriendRequests {
        let route = NetworkRoutes.acceptFriendRequest(id: requestID)
        
        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }
        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }
        
        return try await networkHandler.request(
            url,
            responseType: AccessFriendRequests.self,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }
    
    
}
