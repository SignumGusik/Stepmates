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
    func getLeaderboardItems() async -> [FriendLeaderboardItem] {
        let route = NetworkRoutes.friendsLeaderboard
        let method = route.method
        
        guard let url = route.url,
              let accessToken = tokenStorage.get() else {
            print("No Url access token found")
            return []
        }
        
        do {
            let response = try await networkHandler.request(
                url,
                responseType: [FriendLeaderboardResponse].self,
                httpMethod: method.rawValue,
                accessToken: accessToken.accessToken
            )
            
            return response.map { item in
                FriendLeaderboardItem(
                    username: item.username,
                    place: item.place,
                    steps: item.steps,
                    avatarColor: randomColor(for: item.username),
                    isCurrentUser: item.isMe
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
            UIColor(hex: "#000000") ?? .black,
            UIColor(hex: "#D7A692") ?? .brown
        ]
        
        let index = abs(username.hashValue) % colors.count
        return colors[index]
    }
}
