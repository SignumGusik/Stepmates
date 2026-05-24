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

        func loadDetail() async {
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
            } catch {
                print("group settings detail error:", error)
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

            _ = try await networkHandler.request(
                url,
                responseType: GroupDetailResponse.self,
                httpMethod: route.method.rawValue,
                accessToken: token
            )

            members[index].isAdmin = true
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

            detail = response

            if let avatar {
                try await uploadGroupAvatar(avatar)
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
