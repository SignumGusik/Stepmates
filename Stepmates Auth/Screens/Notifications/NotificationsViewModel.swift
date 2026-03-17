//
//  NotificationsViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 06/02/2026.
//

extension NotificationsViewController {
    class ViewModel {
        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage
        
        init(networkHandler: NetworkHandler, tokenStorage: AccessTokenStorage) {
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }
        
    }
}

extension NotificationsViewController.ViewModel {
    func incomingFriendRequests() async throws -> [AccessFriendRequests] {
        let route = NetworkRoutes.incomingFriendRequest
        
        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }
        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }
        let result = try await networkHandler.request(
                        url,
                        responseType: [AccessFriendRequests].self,
                        httpMethod: route.method.rawValue,
                        accessToken: accessToken)

        return result
    }
    
    func acceptRequest(_ req: AccessFriendRequests) async throws {
            let route = NetworkRoutes.acceptFriendRequest(id: req.id)

            guard let url = route.url else { throw ConfigurationError.nilObject }
            guard let accessToken = tokenStorage.get()?.accessToken else { throw ConfigurationError.nilObject }

            _ = try await networkHandler.request(
                url,
                jsonDictionary: nil,
                httpMethod: route.method.rawValue,
                contentType: ContentType.json.rawValue,
                accessToken: accessToken
            )
        }

    func rejectRequest(_ req: AccessFriendRequests) async throws {
        let route = NetworkRoutes.rejectFriendRequest(id: req.id)

        guard let url = route.url else { throw ConfigurationError.nilObject }
        guard let accessToken = tokenStorage.get()?.accessToken else { throw ConfigurationError.nilObject }

        _ = try await networkHandler.request(
            url,
            jsonDictionary: nil,
            httpMethod: route.method.rawValue,
            contentType: ContentType.json.rawValue,
            accessToken: accessToken
        )
    }
}
