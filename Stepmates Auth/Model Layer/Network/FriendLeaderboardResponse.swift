//
//  FriendLeaderboardResponse.swift
//  Stepmates Auth
//
//  Created by Диана on 16/03/2026.
//

import Foundation

struct FriendLeaderboardResponse: Codable {
    let place: Int
    let userId: Int
    let username: String
    let steps: Int
    let isMe: Bool
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case place
        case userId = "user_id"
        case username
        case steps
        case isMe = "is_me"
        case avatarUrl = "avatar_url"
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
    let goalSteps: Int?
    let isGoalCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case date
        case steps
        case goalSteps = "goal_steps"
        case isGoalCompleted = "is_goal_completed"
    }
}

struct DailyGoalResponse: Decodable {
    let dailyGoalSteps: Int
    let date: String?
    let todaySteps: Int?
    let isGoalCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case dailyGoalSteps = "daily_goal_steps"
        case date
        case todaySteps = "today_steps"
        case isGoalCompleted = "is_goal_completed"
    }
}
