//
//  HomeViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 28/01/2026.
//
import Combine
import Foundation

struct HomeGroupCounterDTO: Decodable {
    let id: Int
}

struct HomeNotificationCounterDTO: Decodable {
    let id: Int
}

struct HomeCounters: Codable {
    let friendsCount: Int
    let groupsCount: Int
    let notificationsCount: Int
    let streakDays: Int
    let dailyGoalSteps: Int?
}

private struct HomeProfileSummary {
    let friendsCount: Int
    let streakDays: Int
    let dailyGoalSteps: Int?
}

extension HomeViewController {
    class ViewModel {
        static let defaultInfoText = "Tap Fetch Button to fetch secured data"

        @Published var infoText = HomeViewController.ViewModel.defaultInfoText

        let username: String
        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage
        private var cachedHomeCounters: HomeCounters?
        private var cachedHomeCountersAt: Date?
        private let homeCountersCacheTTL: TimeInterval = 30

        init(username: String, networkHandler: NetworkHandler, tokenStorage: AccessTokenStorage) {
            self.username = username
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }
    }
}


// MARK: - Actions
extension HomeViewController.ViewModel {
    func resetInfoText() {
        infoText = HomeViewController.ViewModel.self.defaultInfoText
    }

    func fetchSecureData() async throws {
        let route = NetworkRoutes.fatchData
        let method = route.method
        guard let url = route.url,
              let accessToken = tokenStorage.get() else {
            print("No Url access token found")
            throw ConfigurationError.nilObject
        }

        let responseData = try await networkHandler.request(
            url,
            responseType: SecureFetchData.self,
            httpMethod: method.rawValue,
            accessToken: accessToken.accessToken
        )
        infoText = responseData.message
    }

    func syncTodaySteps(_ steps: Int, date: Date = Date()) async -> SyncTodayStepsResponse? {
        let route = NetworkRoutes.syncTodaySteps
        let method = route.method

        guard let url = route.url,
              let accessToken = tokenStorage.get() else {
            print("No Url access token found")
            return nil
        }

        do {
            return try await networkHandler.request(
                url,
                jsonDictionary: [
                    "steps": steps,
                    "date": Self.stepsDateFormatter.string(from: date)
                ],
                responseType: SyncTodayStepsResponse.self,
                httpMethod: method.rawValue,
                accessToken: accessToken.accessToken
            )
        } catch {
            print("syncTodaySteps error: \(error)")
            return nil
        }
    }

    private static let stepsDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func loadTodayStepsState(date: Date = Date()) async -> SyncTodayStepsResponse? {
        let route = NetworkRoutes.myTodaySteps

        guard let url = route.url,
              let accessToken = tokenStorage.get()?.accessToken else {
            return nil
        }

        var requestURL = url
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = [
                URLQueryItem(name: "date", value: Self.stepsDateFormatter.string(from: date))
            ]
            requestURL = components.url ?? url
        }

        do {
            return try await networkHandler.request(
                requestURL,
                responseType: SyncTodayStepsResponse.self,
                httpMethod: route.method.rawValue,
                accessToken: accessToken
            )
        } catch {
            print("loadTodayStepsState error: \(error)")
            return nil
        }
    }

    func updateDailyGoal(_ goal: Int, date: Date = Date()) async throws -> DailyGoalResponse {
        let route = NetworkRoutes.updateDailyGoal

        guard let url = route.url,
              let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            jsonDictionary: [
                "daily_goal_steps": goal,
                "date": Self.stepsDateFormatter.string(from: date)
            ],
            responseType: DailyGoalResponse.self,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }

    func cachedHomeCountersSnapshot() -> HomeCounters? {
        if let cachedHomeCounters {
            return cachedHomeCounters
        }

        guard
            let data = UserDefaults.standard.data(forKey: homeCountersCacheKey),
            let counters = try? JSONDecoder().decode(HomeCounters.self, from: data)
        else {
            return nil
        }

        cachedHomeCounters = counters
        return counters
    }

    func loadHomeCounters(force: Bool = false) async -> HomeCounters {
        if !force,
           let cachedHomeCounters,
           let cachedHomeCountersAt,
           Date().timeIntervalSince(cachedHomeCountersAt) < homeCountersCacheTTL {
            return cachedHomeCounters
        }

        async let profile = loadProfileSummary()
        async let groups = loadGroupsCount()
        async let notifications = loadNotificationsCount()

        let profileSummary = await profile
        let groupsCount = await groups
        let notificationsCount = await notifications
        let counters = HomeCounters(
            friendsCount: profileSummary.friendsCount,
            groupsCount: groupsCount,
            notificationsCount: notificationsCount,
            streakDays: profileSummary.streakDays,
            dailyGoalSteps: profileSummary.dailyGoalSteps
        )

        cachedHomeCounters = counters
        cachedHomeCountersAt = Date()
        saveHomeCountersSnapshot(counters)
        return counters
    }

    private var homeCountersCacheKey: String {
        let rawKey = tokenStorage.get()?.refreshToken ?? username
        let accountKey = Data(rawKey.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
            .prefix(36)

        return "home.counters.\(accountKey)"
    }

    private func saveHomeCountersSnapshot(_ counters: HomeCounters) {
        guard let data = try? JSONEncoder().encode(counters) else { return }
        UserDefaults.standard.set(data, forKey: homeCountersCacheKey)
    }

    private func loadProfileSummary() async -> HomeProfileSummary {
        let route = NetworkRoutes.myProfile

        guard
            let url = route.url,
            let accessToken = tokenStorage.get()?.accessToken
        else {
            return HomeProfileSummary(friendsCount: 0, streakDays: 0, dailyGoalSteps: nil)
        }

        do {
            let profile = try await networkHandler.request(
                url,
                responseType: MyProfileDTO.self,
                httpMethod: route.method.rawValue,
                accessToken: accessToken
            )

            return HomeProfileSummary(
                friendsCount: profile.friendsCount,
                streakDays: profile.currentStreakDays,
                dailyGoalSteps: profile.dailyGoalSteps
            )
        } catch {
            print("profile summary loading error:", error)
            return HomeProfileSummary(
                friendsCount: await loadFriendsCountFallback(),
                streakDays: 0,
                dailyGoalSteps: nil
            )
        }
    }

    private func loadFriendsCountFallback() async -> Int {
        let route = NetworkRoutes.friendsList

        guard
            let url = route.url,
            let accessToken = tokenStorage.get()?.accessToken
        else {
            return 0
        }

        do {
            let friends = try await networkHandler.request(
                url,
                responseType: [AccessUsers].self,
                httpMethod: route.method.rawValue,
                accessToken: accessToken
            )

            return friends.count
        } catch {
            print("friends count fallback loading error:", error)
            return 0
        }
    }

    private func loadGroupsCount() async -> Int {
        let route = NetworkRoutes.groups

        guard
            let baseURL = route.url,
            let accessToken = tokenStorage.get()?.accessToken
        else {
            return 0
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "compact", value: "1")]
        let url = components?.url ?? baseURL

        do {
            let groups = try await networkHandler.request(
                url,
                responseType: [HomeGroupCounterDTO].self,
                httpMethod: route.method.rawValue,
                accessToken: accessToken
            )

            return groups.count
        } catch {
            print("groups count loading error:", error)
            return 0
        }
    }

    private func loadNotificationsCount() async -> Int {
        let route = NetworkRoutes.notifications

        guard
            let url = route.url,
            let accessToken = tokenStorage.get()?.accessToken
        else {
            return 0
        }

        do {
            let notifications = try await networkHandler.request(
                url,
                responseType: [HomeNotificationCounterDTO].self,
                httpMethod: route.method.rawValue,
                accessToken: accessToken
            )

            return notifications.count
        } catch {
            print("notifications count loading error:", error)
            return 0
        }
    }
}
