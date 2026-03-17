//
//  FriendLeaderboardResponse.swift
//  Stepmates Auth
//
//  Created by Диана on 16/03/2026.
//

import Foundation

struct FriendLeaderboardResponse: Decodable {
    let place: Int
    let userId: Int
    let username: String
    let steps: Int
    let isMe: Bool
    
    enum CodingKeys: String, CodingKey {
        case place
        case userId = "user_id"
        case username
        case steps
        case isMe = "is_me"
    }
}

struct SyncTodayStepsBody: Encodable {
    let steps: Int
}

struct SyncTodayStepsResponse: Decodable {
    let id: Int?
    let username: String?
    let date: String?
    let steps: Int?
}
