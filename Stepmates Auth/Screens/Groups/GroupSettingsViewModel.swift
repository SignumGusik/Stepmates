//
//  GroupSettingsViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 09/05/2026.
//
import UIKit

extension GroupSettingsViewController {

    final class ViewModel {

        let group: GroupListItem

        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage
        private let cacheTTL: TimeInterval = 30

        private(set) var detail: GroupDetailResponse?
        private(set) var members: [GroupDraftMember] = []

        var isAdmin: Bool {
            detail?.myIsAdmin ?? group.isAdmin
        }

        init(
            group: GroupListItem,
            networkHandler: NetworkHandler,
            tokenStorage: AccessTokenStorage
        ) {
            self.group = group
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }

        func cachedDetailSnapshot() -> GroupDetailResponse? {
            if let detail {
                return detail
            }

            guard
                let data = UserDefaults.standard.data(forKey: detailCacheKey),
                let response = try? JSONDecoder().decode(GroupDetailResponse.self, from: data)
            else {
                return nil
            }

            applyDetail(response)
            return response
        }

        func loadDetail(force: Bool = false) async {
            if !force,
               let cached = cachedDetailSnapshot(),
               isCacheFresh(cacheDateKey: detailCacheDateKey) {
                applyDetail(cached)
                return
            }

            let route = NetworkRoutes.groupDetail(groupId: group.id)

            guard
                let url = route.url,
                let token = tokenStorage.get()?.accessToken
            else {
                return
            }

            do {
                let response = try await networkHandler.request(
                    url,
                    responseType: GroupDetailResponse.self,
                    httpMethod: route.method.rawValue,
                    accessToken: token
                )

                saveDetailSnapshot(response)
            } catch {
                print("group settings detail error:", error)
                _ = cachedDetailSnapshot()
            }
        }

        func selectedMemberIds() -> Set<Int> {
            Set(members.map { $0.id })
        }

        func addMember(_ user: AccessUsers) async throws {
            guard members.contains(where: { $0.id == user.id }) == false else { return }

            let route = NetworkRoutes.groupAddMember(groupId: group.id)

            guard let url = route.url else {
                throw ConfigurationError.nilObject
            }

            guard let token = tokenStorage.get()?.accessToken else {
                throw ConfigurationError.nilObject
            }

            let response = try await networkHandler.request(
                url,
                jsonDictionary: ["user_id": user.id],
                responseType: GroupDetailResponse.self,
                httpMethod: route.method.rawValue,
                accessToken: token
            )

            saveDetailSnapshot(response)
        }

        func removeMember(at index: Int) async throws {
            guard members.indices.contains(index) else { return }

            let member = members[index]
            let route = NetworkRoutes.groupRemoveMember(groupId: group.id, userId: member.id)

            guard let url = route.url else {
                throw ConfigurationError.nilObject
            }

            guard let token = tokenStorage.get()?.accessToken else {
                throw ConfigurationError.nilObject
            }

            _ = try await networkHandler.request(
                url,
                httpMethod: route.method.rawValue,
                accessToken: token
            )

            members.remove(at: index)
            await loadDetail(force: true)
        }

        func makeAdmin(at index: Int) async throws {
            guard members.indices.contains(index) else { return }

            let member = members[index]
            let route = NetworkRoutes.groupPromoteAdmin(groupId: group.id, userId: member.id)

            guard let url = route.url else {
                throw ConfigurationError.nilObject
            }

            guard let token = tokenStorage.get()?.accessToken else {
                throw ConfigurationError.nilObject
            }

            let response = try await networkHandler.request(
                url,
                responseType: GroupDetailResponse.self,
                httpMethod: route.method.rawValue,
                accessToken: token
            )

            saveDetailSnapshot(response)
        }

        func saveChanges(
            name: String,
            status: String,
            goal: String,
            avatar: UIImage?
        ) async throws {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanGoal = goal.replacingOccurrences(of: " ", with: "")

            guard !trimmedName.isEmpty else {
                throw GroupSettingsError.emptyName
            }

            guard let goalInt = Int(cleanGoal), goalInt > 0 else {
                throw GroupSettingsError.invalidGoal
            }

            let route = NetworkRoutes.updateGroup(groupId: group.id)

            guard let url = route.url else {
                throw ConfigurationError.nilObject
            }

            guard let token = tokenStorage.get()?.accessToken else {
                throw ConfigurationError.nilObject
            }

            let response = try await networkHandler.request(
                url,
                jsonDictionary: [
                    "name": trimmedName,
                    "status": trimmedStatus,
                    "goal_steps": goalInt
                ],
                responseType: GroupDetailResponse.self,
                httpMethod: route.method.rawValue,
                accessToken: token
            )

            saveDetailSnapshot(response)

            if let avatar {
                try await uploadGroupAvatar(avatar)
                await loadDetail(force: true)
            }
        }

        func uploadGroupAvatar(_ image: UIImage) async throws {
            let route = NetworkRoutes.groupAvatar(groupId: group.id)

            guard let url = route.url else {
                throw ConfigurationError.nilObject
            }

            guard let token = tokenStorage.get()?.accessToken else {
                throw ConfigurationError.nilObject
            }

            guard let data = image.jpegData(compressionQuality: 0.85) else {
                throw ConfigurationError.nilObject
            }

            _ = try await networkHandler.uploadAvatar(
                url,
                imageData: data,
                responseType: GroupAvatarUploadResponseDTO.self,
                accessToken: token
            )
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

        private var accountCacheKey: String {
            let rawKey = tokenStorage.get()?.refreshToken ?? "anonymous"
            let accountKey = Data(rawKey.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
                .prefix(36)

            return String(accountKey)
        }

        private var detailCacheKey: String {
            "group.detail.\(accountCacheKey).\(group.id)"
        }

        private var detailCacheDateKey: String {
            detailCacheKey + ".updated_at"
        }

        private func isCacheFresh(cacheDateKey: String) -> Bool {
            guard let cachedAt = UserDefaults.standard.object(forKey: cacheDateKey) as? Date else {
                return false
            }

            return Date().timeIntervalSince(cachedAt) < cacheTTL
        }

        private func saveDetailSnapshot(_ response: GroupDetailResponse) {
            applyDetail(response)

            guard let data = try? JSONEncoder().encode(response) else { return }
            UserDefaults.standard.set(data, forKey: detailCacheKey)
            UserDefaults.standard.set(Date(), forKey: detailCacheDateKey)
        }

        private func applyDetail(_ response: GroupDetailResponse) {
            detail = response
            members = response.members.map { member in
                GroupDraftMember(
                    id: member.id,
                    username: member.username,
                    subtitle: member.firstName.isEmpty ? "участник" : member.firstName,
                    avatarUrl: member.avatarUrl,
                    isAdmin: member.isAdmin,
                    avatarColor: randomColor(for: member.username)
                )
            }
        }
    }
}

enum GroupSettingsError: LocalizedError {
    case emptyName
    case invalidGoal

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Введите название группы."
        case .invalidGoal:
            return "Введите корректную цель группы."
        }
    }
}
