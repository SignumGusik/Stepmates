//
//  FriendLeaderboardItem.swift
//  Stepmates Auth
//
//  Created by Диана on 16/03/2026.
//

import UIKit

struct FriendLeaderboardItem {
    let userId: Int
    let username: String
    let place: Int
    let steps: Int
    let avatarColor: UIColor
    let isCurrentUser: Bool
    let avatarUrl: String?

    var avatarImage: UIImage? = nil

    var isFriend: Bool {
        !isCurrentUser
    }
}
