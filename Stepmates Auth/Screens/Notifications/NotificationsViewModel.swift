//
//  NotificationsViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 06/02/2026.
//


import Foundation

enum NotificationKind: String, Codable {
    case friendRequest = "friend_request"
    case groupInvite = "group_invite"
    case friendRequestAccepted = "friend_request_accepted"
}

struct NotificationUserDTO: Codable {
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

struct NotificationGroupDTO: Codable {
    let id: Int
    let name: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarUrl = "avatar_url"
    }
}

struct AppNotificationDTO: Codable {
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
        private var cachedNotifications: [AppNotificationDTO]?
        private var cachedNotificationsAt: Date?
        private let cacheTTL: TimeInterval = 25

        init(networkHandler: NetworkHandler, tokenStorage: AccessTokenStorage) {
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }
    }
}

extension NotificationsViewController.ViewModel {

    func cachedNotificationsSnapshot() -> [AppNotificationDTO] {
        if let cachedNotifications {
            return cachedNotifications
        }

        guard
            let data = UserDefaults.standard.data(forKey: notificationsCacheKey),
            let notifications = try? JSONDecoder().decode([AppNotificationDTO].self, from: data)
        else {
            return []
        }

        cachedNotifications = notifications
        cachedNotificationsAt = UserDefaults.standard.object(forKey: notificationsCacheDateKey) as? Date
        return notifications
    }

    func saveNotificationsSnapshot(_ notifications: [AppNotificationDTO]) {
        cachedNotifications = notifications
        let now = Date()
        cachedNotificationsAt = now

        guard let data = try? JSONEncoder().encode(notifications) else { return }
        UserDefaults.standard.set(data, forKey: notificationsCacheKey)
        UserDefaults.standard.set(now, forKey: notificationsCacheDateKey)
    }

    func getNotifications(force: Bool = false) async throws -> [AppNotificationDTO] {
        if !force,
           let cachedNotifications,
           let cachedNotificationsAt,
           Date().timeIntervalSince(cachedNotificationsAt) < cacheTTL {
            return cachedNotifications
        }

        let route = NetworkRoutes.notifications

        guard let url = route.url else {
            throw ConfigurationError.nilObject
        }

        guard let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }

        do {
            let notifications = try await networkHandler.request(
                url,
                responseType: [AppNotificationDTO].self,
                httpMethod: route.method.rawValue,
                accessToken: accessToken
            )

            saveNotificationsSnapshot(notifications)
            return notifications
        } catch {
            let cached = cachedNotificationsSnapshot()
            if cached.isEmpty == false {
                return cached
            }

            throw error
        }
    }

    private var notificationsCacheKey: String {
        let rawKey = tokenStorage.get()?.refreshToken ?? "anonymous"
        let accountKey = Data(rawKey.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
            .prefix(36)

        return "notifications.list.\(accountKey)"
    }

    private var notificationsCacheDateKey: String {
        notificationsCacheKey + ".updated_at"
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
