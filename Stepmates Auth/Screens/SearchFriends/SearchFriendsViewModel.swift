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

    func cancelFriendRequest(_ user: AccessUsers) async throws {
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
    }

    func removeFromFriends(_ user: AccessUsers) async throws {
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
    }
    
    func getFriendsForGroupMemberSearch(
        query: String?,
        selectedUserIds: Set<Int>
    ) async -> [AccessUsers] {
        let text = query?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

        do {
            let friends = try await getFriendsList()

            let filteredByText: [AccessUsers]

            if text.isEmpty {
                filteredByText = friends
            } else {
                filteredByText = friends.filter { user in
                    user.username.lowercased().contains(text)
                    || user.email.lowercased().contains(text)
                    || user.firstName.lowercased().contains(text)
                    || user.lastName.lowercased().contains(text)
                }
            }

            return filteredByText.sorted { first, second in
                let firstSelected = selectedUserIds.contains(first.id)
                let secondSelected = selectedUserIds.contains(second.id)

                if firstSelected != secondSelected {
                    return !firstSelected && secondSelected
                }

                return first.username.lowercased() < second.username.lowercased()
            }
        } catch {
            print("friends for group search error: \(error)")
            return []
        }
    }

    private func getFriendsList() async throws -> [AccessUsers] {
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
}
