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

        private let profileCacheTTL: TimeInterval = 60
        private let profileCacheDateKeySuffix = ".updated_at"
        private let avatarUrlKeyPrefix = "profile.avatar_url"
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
        private var accountCacheKey: String {
            let rawKey = tokenStorage.get()?.refreshToken ?? username
            let accountKey = Data(rawKey.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
                .prefix(36)

            return String(accountKey)
        }

        private var localAvatarURL: URL? {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            return dir?.appendingPathComponent("avatar-\(accountCacheKey).jpg")
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
            if let url {
                UserDefaults.standard.set(url, forKey: avatarUrlKey)
            } else {
                UserDefaults.standard.removeObject(forKey: avatarUrlKey)
            }
        }

        func cachedAvatarUrl() -> String? {
            UserDefaults.standard.string(forKey: avatarUrlKey)
        }

        func cachedProfileSnapshot() -> MyProfileDTO? {
            if let profile {
                return profile
            }

            guard
                let data = UserDefaults.standard.data(forKey: profileCacheKey),
                let profile = try? JSONDecoder().decode(MyProfileDTO.self, from: data)
            else {
                return nil
            }

            self.profile = profile
            return profile
        }

        private var profileCacheKey: String {
            "settings.profile.\(accountCacheKey)"
        }

        private var profileCacheDateKey: String {
            profileCacheKey + profileCacheDateKeySuffix
        }

        private var avatarUrlKey: String {
            "\(avatarUrlKeyPrefix).\(accountCacheKey)"
        }

        private func saveProfileSnapshot(_ profile: MyProfileDTO) {
            self.profile = profile

            if let data = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(data, forKey: profileCacheKey)
                UserDefaults.standard.set(Date(), forKey: profileCacheDateKey)
            }

            saveAvatarUrlToCache(profile.avatarUrl)
        }

        // MARK: - Server
        func fetchMyProfile(force: Bool = false) async throws -> MyProfileDTO {
            if !force,
               let cached = cachedProfileSnapshot(),
               let cachedAt = UserDefaults.standard.object(forKey: profileCacheDateKey) as? Date,
               Date().timeIntervalSince(cachedAt) < profileCacheTTL {
                return cached
            }

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

            saveProfileSnapshot(profile)

            return profile
        }
        func syncAvatarIfNeeded(profile: MyProfileDTO? = nil) async throws -> UIImage? {
            let resolvedProfile: MyProfileDTO
            if let profile {
                resolvedProfile = profile
            } else {
                resolvedProfile = try await fetchMyProfile()
            }

            saveAvatarUrlToCache(resolvedProfile.avatarUrl)
            if let local = loadAvatarImage() {
                return local
            }

            guard let urlString = resolvedProfile.avatarUrl else {
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

            saveAvatarImage(image)
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

            return try await fetchMyProfile(force: true)
        }
    }
}
