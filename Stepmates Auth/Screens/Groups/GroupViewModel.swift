//
//  GroupViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 05/05/2026.
//

import Foundation
import UIKit

struct GroupDetailResponse: Codable {
    let id: Int
    let name: String
    let description: String?
    let createdAt: String?
    let members: [GroupDetailMemberResponse]
    let myIsAdmin: Bool
    let avatarUrl: String?
    let membersCount: Int?
    let myPlace: Int?
    let status: String?
    let goalSteps: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdAt = "created_at"
        case members
        case myIsAdmin = "my_is_admin"
        case avatarUrl = "avatar_url"
        case membersCount = "members_count"
        case myPlace = "my_place"
        case status
        case goalSteps = "goal_steps"
    }
}

struct GroupDetailMemberResponse: Codable {
    let id: Int
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let avatarUrl: String?
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case isAdmin = "is_admin"
    }
}

struct GroupLeaderboardResponse: Codable {
    let place: Int
    let userId: Int
    let username: String
    let steps: Int
    let isMe: Bool
    let isAdmin: Bool
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case place
        case userId = "user_id"
        case username
        case steps
        case isMe = "is_me"
        case isAdmin = "is_admin"
        case avatarUrl = "avatar_url"
    }
}

struct GroupLeaderboardItem {
    let place: Int
    let userId: Int
    let username: String
    let steps: Int
    let isCurrentUser: Bool
    let isAdmin: Bool
    let avatarUrl: String?
    let avatarColor: UIColor
}

extension GroupViewController {

    final class ViewModel {
        let group: GroupListItem

        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage
        private var cachedDetail: GroupDetailResponse?
        private var cachedLeaderboards: [String: [GroupLeaderboardItem]] = [:]
        private let cacheTTL: TimeInterval = 30

        init(
            group: GroupListItem,
            networkHandler: NetworkHandler,
            tokenStorage: AccessTokenStorage
        ) {
            self.group = group
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }

        func cachedGroupDetailSnapshot() -> GroupDetailResponse? {
            if let cachedDetail {
                return cachedDetail
            }

            guard
                let data = UserDefaults.standard.data(forKey: detailCacheKey),
                let detail = try? JSONDecoder().decode(GroupDetailResponse.self, from: data)
            else {
                return nil
            }

            cachedDetail = detail
            return detail
        }

        func cachedLeaderboardSnapshot(period: GroupViewController.LeaderboardPeriod) -> [GroupLeaderboardItem] {
            if let cached = cachedLeaderboards[period.rawValue] {
                return cached
            }

            guard
                let data = UserDefaults.standard.data(forKey: leaderboardCacheKey(period: period)),
                let response = try? JSONDecoder().decode([GroupLeaderboardResponse].self, from: data)
            else {
                return []
            }

            let items = mapLeaderboard(response)
            cachedLeaderboards[period.rawValue] = items
            return items
        }

        func getGroupDetail(force: Bool = false) async -> GroupDetailResponse? {
            if !force,
               let cached = cachedGroupDetailSnapshot(),
               isCacheFresh(cacheDateKey: detailCacheDateKey) {
                return cached
            }

            let route = NetworkRoutes.groupDetail(groupId: group.id)

            guard
                let url = route.url,
                let accessToken = tokenStorage.get()?.accessToken
            else {
                return nil
            }

            do {
                let detail = try await networkHandler.request(
                    url,
                    responseType: GroupDetailResponse.self,
                    httpMethod: route.method.rawValue,
                    accessToken: accessToken
                )
                saveGroupDetailSnapshot(detail)
                return detail
            } catch {
                print("group detail error:", error)
                return cachedGroupDetailSnapshot()
            }
        }

        func getLeaderboard(
            period: GroupViewController.LeaderboardPeriod,
            force: Bool = false
        ) async -> [GroupLeaderboardItem] {
            if !force,
               isCacheFresh(cacheDateKey: leaderboardCacheDateKey(period: period)) {
                return cachedLeaderboardSnapshot(period: period)
            }

            let route = NetworkRoutes.groupLeaderboard(
                groupId: group.id,
                period: period.rawValue
            )

            guard
                let url = route.url,
                let accessToken = tokenStorage.get()?.accessToken
            else {
                return []
            }

            do {
                let response = try await networkHandler.request(
                    url,
                    responseType: [GroupLeaderboardResponse].self,
                    httpMethod: route.method.rawValue,
                    accessToken: accessToken
                )

                saveLeaderboardSnapshot(response, period: period)
                return mapLeaderboard(response)
            } catch {
                print("group leaderboard error:", error)
                return cachedLeaderboardSnapshot(period: period)
            }
        }

        func leaveGroup() async throws {
            let route = NetworkRoutes.groupLeave(groupId: group.id)

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

        func totalSteps(from items: [GroupLeaderboardItem]) -> Int {
            items.reduce(0) { $0 + $1.steps }
        }

        func goalSteps(detail: GroupDetailResponse?) -> Int {
            detail?.goalSteps ?? group.goalSteps
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

        private var detailCacheKey: String {
            "group.detail.\(accountCacheKey).\(group.id)"
        }

        private var detailCacheDateKey: String {
            detailCacheKey + ".updated_at"
        }

        private func leaderboardCacheKey(period: GroupViewController.LeaderboardPeriod) -> String {
            "group.leaderboard.\(accountCacheKey).\(group.id).\(period.rawValue)"
        }

        private func leaderboardCacheDateKey(period: GroupViewController.LeaderboardPeriod) -> String {
            leaderboardCacheKey(period: period) + ".updated_at"
        }

        private func isCacheFresh(cacheDateKey: String) -> Bool {
            guard let cachedAt = UserDefaults.standard.object(forKey: cacheDateKey) as? Date else {
                return false
            }

            return Date().timeIntervalSince(cachedAt) < cacheTTL
        }

        private func saveGroupDetailSnapshot(_ detail: GroupDetailResponse) {
            cachedDetail = detail
            guard let data = try? JSONEncoder().encode(detail) else { return }
            UserDefaults.standard.set(data, forKey: detailCacheKey)
            UserDefaults.standard.set(Date(), forKey: detailCacheDateKey)
        }

        private func saveLeaderboardSnapshot(
            _ response: [GroupLeaderboardResponse],
            period: GroupViewController.LeaderboardPeriod
        ) {
            let items = mapLeaderboard(response)
            cachedLeaderboards[period.rawValue] = items

            guard let data = try? JSONEncoder().encode(response) else { return }
            UserDefaults.standard.set(data, forKey: leaderboardCacheKey(period: period))
            UserDefaults.standard.set(Date(), forKey: leaderboardCacheDateKey(period: period))
        }

        private func mapLeaderboard(_ response: [GroupLeaderboardResponse]) -> [GroupLeaderboardItem] {
            response.map { item in
                GroupLeaderboardItem(
                    place: item.place,
                    userId: item.userId,
                    username: item.username,
                    steps: item.steps,
                    isCurrentUser: item.isMe,
                    isAdmin: item.isAdmin,
                    avatarUrl: item.avatarUrl,
                    avatarColor: randomColor(for: item.username)
                )
            }
        }
    }
}
