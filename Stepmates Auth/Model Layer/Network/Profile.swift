//
//  Profile.swift
//  Stepmates Auth
//
//  Created by Диана on 20/04/2026.
//

import Foundation

struct MyProfileDTO: Decodable {
    let id: Int
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let avatarUrl: String?

    let currentStreakDays: Int
    let totalSteps: Int
    let friendsCount: Int
    let friendsPreview: [ProfileFriendPreviewDTO]
    let achievements: [ProfileAchievementDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case currentStreakDays = "current_streak_days"
        case totalSteps = "total_steps"
        case friendsCount = "friends_count"
        case friendsPreview = "friends_preview"
        case achievements
    }
}

struct ProfileFriendPreviewDTO: Decodable {
    let id: Int
    let username: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
    }
}

struct ProfileAchievementDTO: Decodable {
    let code: String
    let title: String
    let current: Int
    let target: Int
    let progress: Double
    let isFinished: Bool
    var shortTitle: String {
        switch code {
        case "streaks_1":
            return "Первый"
        case "streaks_7":
            return "7 дней"
        case "streaks_14":
            return "14 дней"
        case "streaks_30":
            return "30 дней"
        case "total_200000":
            return "200 000"
        default:
            return title
        }
    }

    var shortSubtitle: String {
        switch code {
        case "streaks_1":
            return "первый стрейк"
        case "streaks_7":
            return "стрейк подряд"
        case "streaks_14":
            return "стрейк подряд"
        case "streaks_30":
            return "стрейк подряд"
        case "total_200000":
            return "шагов всего"
        default:
            return ""
        }
    }

    enum CodingKeys: String, CodingKey {
        case code
        case title
        case current
        case target
        case progress
        case isFinished = "is_finished"
    }

    var imageName: String {
        isFinished ? "\(code)_complete" : "\(code)_finished"
    }
}
struct AvatarUploadResponseDTO: Decodable {
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
    }
}
