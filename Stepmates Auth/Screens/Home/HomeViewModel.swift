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
}

extension HomeViewController {
    class ViewModel {
        static let defaultInfoText = "Tap Fetch Button to fetch secured data"
        
        @Published var infoText = HomeViewController.ViewModel.defaultInfoText
        
        let username: String
        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage
        
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
    
    func syncTodaySteps(_ steps: Int) async {
        let route = NetworkRoutes.syncTodaySteps
        let method = route.method
        
        guard let url = route.url,
              let accessToken = tokenStorage.get() else {
            print("No Url access token found")
            return
        }
        
        do {
            _ = try await networkHandler.request(
                url,
                jsonDictionary: ["steps": steps],
                responseType: SyncTodayStepsResponse.self,
                httpMethod: method.rawValue,
                accessToken: accessToken.accessToken
            )
        } catch {
            print("syncTodaySteps error: \(error)")
        }
    }
    
    func loadHomeCounters() async -> HomeCounters {
        async let friends = loadFriendsCount()
        async let groups = loadGroupsCount()
        async let notifications = loadNotificationsCount()

        return await HomeCounters(
            friendsCount: friends,
            groupsCount: groups,
            notificationsCount: notifications
        )
    }

    private func loadFriendsCount() async -> Int {
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
            print("friends count loading error:", error)
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
