//
//  UserCard.swift
//  Stepmates Auth
//
//  Created by Диана on 22/04/2026.
//

import Foundation

struct UserCardDTO: Decodable {
    let id: Int
    let username: String
    let avatarUrl: String?

    let isFriend: Bool
    let requestSent: Bool
    let requestReceived: Bool

    let friendsCount: Int
    let mutualFriendsCount: Int

    let friendsPreviewAvatarUrls: [String]
    let mutualPreviewAvatarUrls: [String]

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarUrl = "avatar_url"
        case isFriend = "is_friend"
        case requestSent = "request_sent"
        case requestReceived = "request_received"
        case friendsCount = "friends_count"
        case mutualFriendsCount = "mutual_friends_count"
        case friendsPreviewAvatarUrls = "friends_preview_avatar_urls"
        case mutualPreviewAvatarUrls = "mutual_preview_avatar_urls"
    }
}
