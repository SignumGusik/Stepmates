//
//  FriendsViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 02/02/2026.
//

import Foundation
import UIKit

extension FriendsViewController {
    final class ViewModel {
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

extension FriendsViewController.ViewModel {

    func getLeaderboardItems(period: FriendsViewController.LeaderboardPeriod) async -> [FriendLeaderboardItem] {
        let route = NetworkRoutes.friendsLeaderboard

        guard
            let baseURL = route.url,
            let accessToken = tokenStorage.get()?.accessToken
        else {
            print("No Url/access token found")
            return []
        }

        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var q = comps?.queryItems ?? []
        q.append(URLQueryItem(name: "period", value: period.rawValue))
        comps?.queryItems = q

        guard let url = comps?.url else {
            print("Could not build URLComponents url")
            return []
        }

        do {
            let response = try await networkHandler.request(
                url,
                responseType: [FriendLeaderboardResponse].self,
                httpMethod: route.method.rawValue,
                accessToken: accessToken
            )

            return response.map { item in
                FriendLeaderboardItem(
                    userId: item.userId,
                    username: item.username,
                    place: item.place,
                    steps: item.steps,
                    avatarColor: randomColor(for: item.username),
                    isCurrentUser: item.isMe,
                    avatarUrl: item.avatarUrl,
                    avatarImage: nil
                )
            }
        } catch {
            print("leaderboard error: \(error)")
            return []
        }
    }

    private func randomColor(for username: String) -> UIColor {
        let colors: [UIColor] = [
            Constants.purple ?? .systemBlue,
            Constants.orange ?? .orange,
            Constants.blue ?? .blue,
            UIColor(hex: "#D8DDF8") ?? .systemGray4,
            UIColor(hex: "#D7A692") ?? .brown
        ]

        let index = abs(username.hashValue) % colors.count
        return colors[index]
    }
}
