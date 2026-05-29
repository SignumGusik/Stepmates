//
//  GroupsViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 21/02/2026.
//

import Foundation

struct GroupResponse: Decodable {
    let id: Int
    let name: String
    let description: String?
    let createdAt: String?
    let isAdmin: Bool
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
        case isAdmin = "is_admin"
        case avatarUrl = "avatar_url"
        case membersCount = "members_count"
        case myPlace = "my_place"
        case status
        case goalSteps = "goal_steps"
    }
}

struct GroupListItem: Codable {
    let id: Int
    let name: String
    let description: String
    let isAdmin: Bool
    let avatarUrl: String?
    let membersCount: Int
    let myPlace: Int?
    let status: String
    let goalSteps: Int
}

extension GroupsViewController {

    final class ViewModel {
        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage

        init(
            networkHandler: NetworkHandler,
            tokenStorage: AccessTokenStorage
        ) {
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }
    }
}

extension GroupsViewController.ViewModel {
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

    func cachedGroupsSnapshot() -> [GroupListItem] {
        guard
            let data = UserDefaults.standard.data(forKey: groupsCacheKey),
            let groups = try? JSONDecoder().decode([GroupListItem].self, from: data)
        else {
            return []
        }

        return groups
    }

    func getGroups() async -> [GroupListItem] {
        let route = NetworkRoutes.groups

        guard
            let baseURL = route.url,
            let accessToken = tokenStorage.get()?.accessToken
        else {
            print("No url/access token found")
            return []
        }

        var url = baseURL
        if var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) {
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "date", value: Self.localDateString()))
            components.queryItems = queryItems
            url = components.url ?? baseURL
        }

        do {
            let response = try await networkHandler.request(
                url,
                responseType: [GroupResponse].self,
                httpMethod: route.method.rawValue,
                accessToken: accessToken
            )

            let groups = response.map { group in
                GroupListItem(
                    id: group.id,
                    name: group.name,
                    description: group.description ?? "",
                    isAdmin: group.isAdmin,
                    avatarUrl: group.avatarUrl,
                    membersCount: group.membersCount ?? 0,
                    myPlace: group.myPlace,
                    status: group.status ?? "",
                    goalSteps: group.goalSteps ?? 300_000
                )
            }

            saveGroupsSnapshot(groups)
            return groups
        } catch {
            print("groups loading error: \(error)")
            return cachedGroupsSnapshot()
        }
    }

    private var groupsCacheKey: String {
        let rawKey = tokenStorage.get()?.refreshToken ?? "anonymous"
        let accountKey = Data(rawKey.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
            .prefix(36)

        return "groups.list.\(accountKey).\(Self.localDateString())"
    }

    private func saveGroupsSnapshot(_ groups: [GroupListItem]) {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        UserDefaults.standard.set(data, forKey: groupsCacheKey)
    }
}
