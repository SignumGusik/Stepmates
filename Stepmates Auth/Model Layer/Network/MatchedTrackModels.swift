//
//  MatchedTrackModels.swift
//  Stepmates Auth
//
//  Created by Диана on 30/04/2026.
//

import Foundation

struct MatchedDisplayPoint: Decodable {
    let latitude: Double
    let longitude: Double
    let confidenceScore: Int?
    let movementKind: String?
    let breakReason: String?
    
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case confidenceScore = "confidence_score"
        case movementKind = "movement_kind"
        case breakReason = "break_reason"
    }
}

struct MatchedTrackSegmentResponse: Decodable {
    let startedAt: String
    let endedAt: String
    let status: String
    let signalQuality: String?
    let matchingConfidence: String?
    let confidenceScore: Int?
    let movementState: String?
    let movementKind: String?
    let breakReason: String?
    let displayPoints: [MatchedDisplayPoint]

    enum CodingKeys: String, CodingKey {
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case status
        case signalQuality = "signal_quality"
        case matchingConfidence = "matching_confidence"
        case confidenceScore = "confidence_score"
        case movementState = "movement_state"
        case movementKind = "movement_kind"
        case breakReason = "break_reason"
        case displayPoints = "display_points"
    }
}

struct FriendMatchedTrackResponse: Decodable {
    let userId: Int
    let username: String
    let avatarUrl: String?
    let segments: [MatchedTrackSegmentResponse]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case segments
    }
}
