//
//  NotificationsViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 06/02/2026.
//


import Foundation

enum NotificationKind: String, Decodable {
    case friendRequest = "friend_request"
    case groupInvite = "group_invite"
    case friendRequestAccepted = "friend_request_accepted"
}

struct NotificationUserDTO: Decodable {
    let id: Int
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
    }
}

struct NotificationGroupDTO: Decodable {
    let id: Int
    let name: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarUrl = "avatar_url"
    }
}

struct AppNotificationDTO: Decodable {
    let id: Int
    let type: NotificationKind
    let createdAt: String
    let fromUser: NotificationUserDTO?
    let toUser: NotificationUserDTO?
    let group: NotificationGroupDTO?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case createdAt = "created_at"
        case fromUser = "from_user"
        case toUser = "to_user"
        case group
        case status
    }
}

extension NotificationsViewController {

    final class ViewModel {
        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage

        init(networkHandler: NetworkHandler, tokenStorage: AccessTokenStorage) {
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }
    }
}

extension NotificationsViewController.ViewModel {

    func getNotifications() async throws -> [AppNotificationDTO] {
        let route = NetworkRoutes.notifications

        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }

        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            responseType: [AppNotificationDTO].self,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }

    func acceptFriendRequest(id: Int) async throws {
        let route = NetworkRoutes.acceptFriendRequest(id: id)

        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }

        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }

        _ = try await networkHandler.request(
            url,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }

    func rejectFriendRequest(id: Int) async throws {
        let route = NetworkRoutes.rejectFriendRequest(id: id)

        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }

        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }

        _ = try await networkHandler.request(
            url,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }

    func acceptGroupInvite(id: Int) async throws {
        let route = NetworkRoutes.acceptGroupInvite(inviteId: id)

        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }

        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }

        _ = try await networkHandler.request(
            url,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }

    func rejectGroupInvite(id: Int) async throws {
        let route = NetworkRoutes.rejectGroupInvite(inviteId: id)

        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }

        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }

        _ = try await networkHandler.request(
            url,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }
    func dismissFriendAcceptedNotification(id: Int) async throws {
        let route = NetworkRoutes.dismissFriendAcceptedNotification(requestId: id)

        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }

        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }

        _ = try await networkHandler.request(
            url,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }
}
