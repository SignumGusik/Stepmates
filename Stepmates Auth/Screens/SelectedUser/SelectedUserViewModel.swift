//
//  SelectedUserViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 06/02/2026.
//


import Foundation
import UIKit

enum SelectedUserProfileSource {
    case search
    case leaderboard
}

extension SelectedUserViewController {
    final class ViewModel {

        var user: AccessUsers
        let source: SelectedUserProfileSource
        let isOwnProfile: Bool

        private let networkHandler: NetworkHandler
        private let friendsService: FriendsService
        private let tokenStorage: AccessTokenStorage

        private(set) var friendsCount: Int = 0
        private(set) var mutualFriendsCount: Int = 0
        private(set) var friendsPreviewAvatarUrls: [String] = []
        private(set) var mutualPreviewAvatarUrls: [String] = []

        init(
            user: AccessUsers,
            source: SelectedUserProfileSource = .search,
            isOwnProfile: Bool = false,
            networkHandler: NetworkHandler,
            friendsService: FriendsService,
            tokenStorage: AccessTokenStorage
        ) {
            self.user = user
            self.source = source
            self.isOwnProfile = isOwnProfile
            self.networkHandler = networkHandler
            self.friendsService = friendsService
            self.tokenStorage = tokenStorage
        }
    }
}
extension SelectedUserViewController.ViewModel {

    func fetchUserCard() async throws {
        let route = NetworkRoutes.userCard(id: user.id)

        guard let url = route.url else { throw ConfigurationError.nilObject }
        guard let accessToken = tokenStorage.get()?.accessToken else { throw ConfigurationError.nilObject }

        let dto = try await networkHandler.request(
            url,
            responseType: UserCardDTO.self,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )

        friendsCount = dto.friendsCount
        mutualFriendsCount = dto.mutualFriendsCount
        friendsPreviewAvatarUrls = dto.friendsPreviewAvatarUrls
        mutualPreviewAvatarUrls = dto.mutualPreviewAvatarUrls

        user.username = dto.username
        user.avatarUrl = dto.avatarUrl

        switch source {
        case .search:
            user.isFriend = dto.isFriend
            user.requestSent = dto.requestSent
            user.requestReceived = dto.requestReceived

        case .leaderboard:
            user.isFriend = true
            user.requestSent = false
            user.requestReceived = false
        }
    }

    func addToFriends() async throws {
        _ = try await friendsService.sendFriendRequest(toUserID: user.id)
        user.requestSent = true
        user.requestReceived = false
        user.isFriend = false
    }

    func cancelFriendRequest() async throws {
        let route = NetworkRoutes.cancelFriendRequest(userID: user.id)

        guard let url = route.url else { throw ConfigurationError.nilObject }
        guard let accessToken = tokenStorage.get()?.accessToken else { throw ConfigurationError.nilObject }

        var request = URLRequest(url: url)
        request.httpMethod = route.method.rawValue
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        user.requestSent = false
        user.requestReceived = false
        user.isFriend = false
    }

    func removeFromFriends() async throws {
        let route = NetworkRoutes.removeFriend(userID: user.id)

        guard let url = route.url else { throw ConfigurationError.nilObject }
        guard let accessToken = tokenStorage.get()?.accessToken else { throw ConfigurationError.nilObject }

        var request = URLRequest(url: url)
        request.httpMethod = route.method.rawValue
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        user.isFriend = false
        user.requestSent = false
        user.requestReceived = false
    }
}
