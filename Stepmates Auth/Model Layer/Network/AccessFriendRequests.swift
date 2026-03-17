//
//  AccessFriendRequests.swift
//  Stepmates Auth
//
//  Created by Диана on 30/01/2026.
//

import Foundation

struct AccessFriendRequests: Codable {
    let id: Int
    let fromUser: AccessUsers
    let toUser: AccessUsers
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case fromUser = "from_user"
        case toUser = "to_user"
        case status
        case createdAt = "created_at"
    }
}
