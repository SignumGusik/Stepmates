//
//  GroupViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 05/05/2026.
//

import Foundation
import UIKit

struct GroupDetailResponse: Decodable {
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

struct GroupDetailMemberResponse: Decodable {
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

struct GroupLeaderboardResponse: Decodable {
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

        init(
            group: GroupListItem,
            networkHandler: NetworkHandler,
            tokenStorage: AccessTokenStorage
        ) {
            self.group = group
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }

        func getGroupDetail() async -> GroupDetailResponse? {
            let route = NetworkRoutes.groupDetail(groupId: group.id)

            guard
                let url = route.url,
                let accessToken = tokenStorage.get()?.accessToken
            else {
                return nil
            }

            do {
                return try await networkHandler.request(
                    url,
                    responseType: GroupDetailResponse.self,
                    httpMethod: route.method.rawValue,
                    accessToken: accessToken
                )
            } catch {
                print("group detail error:", error)
                return nil
            }
        }

        func getLeaderboard(period: GroupViewController.LeaderboardPeriod) async -> [GroupLeaderboardItem] {
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

                return response.map { item in
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
            } catch {
                print("group leaderboard error:", error)
                return []
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
    }
}
