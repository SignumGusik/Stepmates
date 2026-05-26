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

struct HomeCounters {
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

    func syncTodaySteps(_ steps: Int) async -> SyncTodayStepsResponse? {
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
                jsonDictionary: ["steps": steps],
                responseType: SyncTodayStepsResponse.self,
                httpMethod: method.rawValue,
                accessToken: accessToken.accessToken
            )
        } catch {
            print("syncTodaySteps error: \(error)")
            return nil
        }
    }

    func loadTodayStepsState() async -> SyncTodayStepsResponse? {
        let route = NetworkRoutes.myTodaySteps

        guard let url = route.url,
              let accessToken = tokenStorage.get()?.accessToken else {
            return nil
        }

        do {
            return try await networkHandler.request(
                url,
                responseType: SyncTodayStepsResponse.self,
                httpMethod: route.method.rawValue,
                accessToken: accessToken
            )
        } catch {
            print("loadTodayStepsState error: \(error)")
            return nil
        }
    }

    func updateDailyGoal(_ goal: Int) async throws -> DailyGoalResponse {
        let route = NetworkRoutes.updateDailyGoal

        guard let url = route.url,
              let accessToken = tokenStorage.get()?.accessToken else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            jsonDictionary: ["daily_goal_steps": goal],
            responseType: DailyGoalResponse.self,
            httpMethod: route.method.rawValue,
            accessToken: accessToken
        )
    }

    func loadHomeCounters() async -> HomeCounters {
        if let cachedHomeCounters,
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
        return counters
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
            let url = route.url,
            let accessToken = tokenStorage.get()?.accessToken
        else {
            return 0
        }

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
