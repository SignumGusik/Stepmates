//
//  FriendLiveLocation.swift
//  Stepmates Auth
//
//  Created by Диана on 21/04/2026.
//

import Foundation

final class FriendLiveLocation: NSObject, Decodable {
    let userId: Int
    let username: String
    let avatarUrl: String?
    let latitude: Double
    let longitude: Double
    let updatedAt: String
    let isMe: Bool
    let horizontalAccuracy: Double?
    let confidenceScore: Int?
    let movementState: String?
    let movementKind: String?
    let signalQuality: String?

    init(
        userId: Int,
        username: String,
        avatarUrl: String?,
        latitude: Double,
        longitude: Double,
        updatedAt: String,
        isMe: Bool,
        horizontalAccuracy: Double? = nil,
        confidenceScore: Int? = nil,
        movementState: String? = nil,
        movementKind: String? = nil,
        signalQuality: String? = nil
    ) {
        self.userId = userId
        self.username = username
        self.avatarUrl = avatarUrl
        self.latitude = latitude
        self.longitude = longitude
        self.updatedAt = updatedAt
        self.isMe = isMe
        self.horizontalAccuracy = horizontalAccuracy
        self.confidenceScore = confidenceScore
        self.movementState = movementState
        self.movementKind = movementKind
        self.signalQuality = signalQuality
        super.init()
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case latitude
        case longitude
        case updatedAt = "updated_at"
        case isMe = "is_me"
        case horizontalAccuracy = "horizontal_accuracy"
        case confidenceScore = "confidence_score"
        case movementState = "movement_state"
        case movementKind = "movement_kind"
        case signalQuality = "signal_quality"
    }
}
