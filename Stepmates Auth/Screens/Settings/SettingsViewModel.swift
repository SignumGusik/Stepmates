//
//  SettingsViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 17/03/2026.
//

import UIKit

extension SettingsViewController {
    final class ViewModel {
        let username: String
        let avatarColor: UIColor

        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage

        private let avatarFileName = "avatar.jpg"
        private let avatarUrlKey = "profile.avatar_url"
        private(set) var profile: MyProfileDTO?

        init(username: String,
             networkHandler: NetworkHandler,
             tokenStorage: AccessTokenStorage) {
            self.username = username
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
            self.avatarColor = ViewModel.randomColor(for: username)
        }
        
        private static func randomColor(for username: String) -> UIColor {
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

        // MARK: - Local storage
        private var localAvatarURL: URL? {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            return dir?.appendingPathComponent(avatarFileName)
        }

        func saveAvatarImage(_ image: UIImage) {
            guard let url = localAvatarURL else { return }
            guard let data = image.jpegData(compressionQuality: 0.85) else { return }
            try? data.write(to: url, options: [.atomic])
        }

        func loadAvatarImage() -> UIImage? {
            guard let url = localAvatarURL else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }

        func deleteLocalAvatar() {
            guard let url = localAvatarURL else { return }
            try? FileManager.default.removeItem(at: url)
        }

        private func saveAvatarUrlToCache(_ url: String?) {
            UserDefaults.standard.setValue(url, forKey: avatarUrlKey)
        }

        func cachedAvatarUrl() -> String? {
            UserDefaults.standard.string(forKey: avatarUrlKey)
        }

        // MARK: - Server
        func fetchMyProfile() async throws -> MyProfileDTO {
            let route = NetworkRoutes.myProfile

            guard let url = route.url else {
                throw ConfigurationError.nilObject
            }

            guard let token = tokenStorage.get()?.accessToken else {
                throw ConfigurationError.nilObject
            }

            let profile = try await networkHandler.request(
                url,
                responseType: MyProfileDTO.self,
                httpMethod: route.method.rawValue,
                accessToken: token
            )

            self.profile = profile
            saveAvatarUrlToCache(profile.avatarUrl)

            return profile
        }
        func syncAvatarIfNeeded() async throws -> UIImage? {
            let profile = try await fetchMyProfile()
            saveAvatarUrlToCache(profile.avatarUrl)
            if let local = loadAvatarImage() {
                return local
            }

            guard let urlString = profile.avatarUrl else {
                return nil
            }

            guard let image = await AvatarLoader.shared.loadImage(urlString: urlString) else {
                return nil
            }

            saveAvatarImage(image)
            return image
        }

        func uploadAvatarToServer(_ image: UIImage) async throws -> String? {
            let route = NetworkRoutes.profileAvatar
            guard let url = route.url else { throw ConfigurationError.nilObject }
            guard let token = tokenStorage.get()?.accessToken else { throw ConfigurationError.nilObject }

            guard let data = image.jpegData(compressionQuality: 0.85) else {
                throw ConfigurationError.nilObject
            }

            let resp = try await networkHandler.uploadAvatar(
                url,
                imageData: data,
                responseType: AvatarUploadResponseDTO.self,
                accessToken: token
            )

            saveAvatarUrlToCache(resp.avatarUrl)
            return resp.avatarUrl
        }
        func deleteAvatarRemoteAndLocal() async throws {
            let route = NetworkRoutes.deleteProfileAvatar
            guard let url = route.url else { throw ConfigurationError.nilObject }
            guard let token = tokenStorage.get()?.accessToken else { throw ConfigurationError.nilObject }

            _ = try await networkHandler.request(
                url,
                responseType: ApiMessageDTO.self,
                httpMethod: route.method.rawValue,
                accessToken: token
            )
            deleteLocalAvatar()
            saveAvatarUrlToCache(nil)
        }
        
        func updateUsername(_ username: String) async throws -> MyProfileDTO {
            let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmed.isEmpty == false else {
                throw SettingsProfileError.emptyUsername
            }

            let route = NetworkRoutes.setUsername

            guard let url = route.url else {
                throw ConfigurationError.nilObject
            }

            guard let token = tokenStorage.get()?.accessToken else {
                throw ConfigurationError.nilObject
            }

            _ = try await networkHandler.request(
                url,
                jsonDictionary: ["username": trimmed],
                httpMethod: route.method.rawValue,
                accessToken: token
            )

            return try await fetchMyProfile()
        }
    }
}
