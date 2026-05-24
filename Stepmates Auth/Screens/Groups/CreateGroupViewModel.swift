//
//  CreateGroupViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 05/05/2026.
//

import Foundation
import UIKit

struct CreatedGroupResponse: Decodable {
    let id: Int
    let name: String
    let description: String?
    let createdAt: String?
    let members: [CreatedGroupMemberResponse]
    let myIsAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdAt = "created_at"
        case members
        case myIsAdmin = "my_is_admin"
    }
}

struct CreatedGroupMemberResponse: Decodable {
    let id: Int
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let isAdmin: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case isAdmin = "is_admin"
        case createdAt = "created_at"
    }
}

struct GroupDraftMember {
    let id: Int
    let username: String
    let subtitle: String
    let avatarUrl: String?
    var isAdmin: Bool
    let avatarColor: UIColor
}

struct GroupAvatarUploadResponseDTO: Decodable {
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
    }
}

extension CreateGroupViewController {

    final class ViewModel {

        private let networkHandler: NetworkHandler
        private let tokenStorage: AccessTokenStorage

        private(set) var members: [GroupDraftMember] = []

        init(
            networkHandler: NetworkHandler,
            tokenStorage: AccessTokenStorage
        ) {
            self.networkHandler = networkHandler
            self.tokenStorage = tokenStorage
        }

        func addMember(_ user: AccessUsers) {
            guard members.contains(where: { $0.id == user.id }) == false else { return }

            let member = GroupDraftMember(
                id: user.id,
                username: user.username,
                subtitle: "друг",
                avatarUrl: user.avatarUrl,
                isAdmin: false,
                avatarColor: randomColor(for: user.username)
            )

            members.append(member)
        }

        func selectedMemberIds() -> Set<Int> {
            Set(members.map { $0.id })
        }

        func removeMember(at index: Int) {
            guard members.indices.contains(index) else { return }
            members.remove(at: index)
        }

        func makeAdmin(at index: Int) {
            guard members.indices.contains(index) else { return }
            members[index].isAdmin = true
        }

        func canCreateGroup() -> Bool {
            return members.count + 1 >= 3
        }

        func createGroup(name: String, description: String, avatar: UIImage?) async throws {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedName.isEmpty else {
                throw CreateGroupError.emptyName
            }

            guard canCreateGroup() else {
                throw CreateGroupError.notEnoughMembers
            }

            let createRoute = NetworkRoutes.createGroup

            guard let createURL = createRoute.url else {
                throw ConfigurationError.nilObject
            }

            guard let token = tokenStorage.get()?.accessToken else {
                throw ConfigurationError.nilObject
            }

            let createdGroup = try await networkHandler.request(
                createURL,
                jsonDictionary: [
                    "name": trimmedName,
                    "description": trimmedDescription
                ],
                responseType: CreatedGroupResponse.self,
                httpMethod: createRoute.method.rawValue,
                accessToken: token
            )
            if let avatar {
                try await uploadGroupAvatarToServer(avatar, groupId: createdGroup.id)
            }
            

            for member in members {
                let addRoute = NetworkRoutes.groupAddMember(groupId: createdGroup.id)

                guard let addURL = addRoute.url else {
                    continue
                }

                _ = try await networkHandler.request(
                    addURL,
                    jsonDictionary: [
                        "user_id": member.id
                    ],
                    responseType: CreatedGroupResponse.self,
                    httpMethod: addRoute.method.rawValue,
                    accessToken: token
                )
                
                if member.isAdmin {
                    let promoteRoute = NetworkRoutes.groupPromoteAdmin(
                        groupId: createdGroup.id,
                        userId: member.id
                    )

                    guard let promoteURL = promoteRoute.url else {
                        continue
                    }

                    _ = try await networkHandler.request(
                        promoteURL,
                        responseType: CreatedGroupResponse.self,
                        httpMethod: promoteRoute.method.rawValue,
                        accessToken: token
                    )
                }
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
        
        func uploadGroupAvatarToServer(_ image: UIImage, groupId: Int) async throws {
            let route = NetworkRoutes.groupAvatar(groupId: groupId)

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
    }
}

enum CreateGroupError: LocalizedError {
    case emptyName
    case notEnoughMembers

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Введите название группы."
        case .notEnoughMembers:
            return "В группе должно быть минимум 3 участника."
        }
    }
}
