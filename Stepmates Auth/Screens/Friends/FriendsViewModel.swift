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
        private var cachedLeaderboards: [String: [FriendLeaderboardItem]] = [:]
        private let cacheTTL: TimeInterval = 30

        init(networkHandler: NetworkHandler, friendsService: FriendsService, tokenStorage: AccessTokenStorage) {
            self.networkHandler = networkHandler
            self.friendsService = friendsService
            self.tokenStorage = tokenStorage
        }
    }
}

extension FriendsViewController.ViewModel {
    private static var localDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func localDateString(for date: Date = Date()) -> String {
        localDateFormatter.string(from: date)
    }

    func cachedLeaderboardSnapshot(period: FriendsViewController.LeaderboardPeriod) -> [FriendLeaderboardItem] {
        let cacheKey = leaderboardMemoryCacheKey(period: period)

        if let cached = cachedLeaderboards[cacheKey] {
            return cached
        }

        guard
            let data = UserDefaults.standard.data(forKey: leaderboardCacheKey(period: period)),
            let response = try? JSONDecoder().decode([FriendLeaderboardResponse].self, from: data)
        else {
            return []
        }

        let items = mapLeaderboard(response)
        cachedLeaderboards[cacheKey] = items
        return items
    }

    func getLeaderboardItems(
        period: FriendsViewController.LeaderboardPeriod,
        force: Bool = false
    ) async -> [FriendLeaderboardItem] {
        if !force,
           isCacheFresh(cacheDateKey: leaderboardCacheDateKey(period: period)) {
            return cachedLeaderboardSnapshot(period: period)
        }

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
        q.append(URLQueryItem(name: "date", value: Self.localDateString()))
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

            saveLeaderboardSnapshot(response, period: period)
            return mapLeaderboard(response)
        } catch {
            print("leaderboard error: \(error)")
            return cachedLeaderboardSnapshot(period: period)
        }
    }

    private var accountCacheKey: String {
        let rawKey = tokenStorage.get()?.refreshToken ?? "anonymous"
        let accountKey = Data(rawKey.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
            .prefix(36)

        return String(accountKey)
    }

    private func leaderboardCacheKey(period: FriendsViewController.LeaderboardPeriod) -> String {
        "friends.leaderboard.\(accountCacheKey).\(leaderboardMemoryCacheKey(period: period))"
    }

    private func leaderboardMemoryCacheKey(period: FriendsViewController.LeaderboardPeriod) -> String {
        "\(period.rawValue).\(Self.localDateString())"
    }

    private func leaderboardCacheDateKey(period: FriendsViewController.LeaderboardPeriod) -> String {
        leaderboardCacheKey(period: period) + ".updated_at"
    }

    private func isCacheFresh(cacheDateKey: String) -> Bool {
        guard let cachedAt = UserDefaults.standard.object(forKey: cacheDateKey) as? Date else {
            return false
        }

        return Date().timeIntervalSince(cachedAt) < cacheTTL
    }

    private func saveLeaderboardSnapshot(
        _ response: [FriendLeaderboardResponse],
        period: FriendsViewController.LeaderboardPeriod
    ) {
        let items = mapLeaderboard(response)
        cachedLeaderboards[leaderboardMemoryCacheKey(period: period)] = items

        guard let data = try? JSONEncoder().encode(response) else { return }
        UserDefaults.standard.set(data, forKey: leaderboardCacheKey(period: period))
        UserDefaults.standard.set(Date(), forKey: leaderboardCacheDateKey(period: period))
    }

    private func mapLeaderboard(_ response: [FriendLeaderboardResponse]) -> [FriendLeaderboardItem] {
        response.map { item in
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
