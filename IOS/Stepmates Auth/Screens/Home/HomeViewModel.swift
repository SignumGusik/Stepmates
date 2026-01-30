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
        
        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage
        
        init(networkHandler: NetworkHandler, tokenStorage: AccessTokenStorage) {
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
        
}
