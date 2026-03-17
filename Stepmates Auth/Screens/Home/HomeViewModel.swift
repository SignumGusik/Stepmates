//
//  HomeViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 28/01/2026.
//
import Combine
import Foundation

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
}
