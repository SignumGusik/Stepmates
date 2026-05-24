//
//  TrackPointPayload.swift
//  Stepmates Auth
//
//  Created by Диана on 29/04/2026.
//

import Foundation

struct TrackPointPayload: Codable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double?
    let speed: Double?
    let course: Double?
    let movementState: String?
    let stepsDelta: Int?
    let confidenceScore: Int?
    let movementKind: String?
    let breakReason: String?
    let recordedAt: String

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case horizontalAccuracy = "horizontal_accuracy"
        case speed
        case course
        case movementState = "movement_state"
        case stepsDelta = "steps_delta"
        case confidenceScore = "confidence_score"
        case movementKind = "movement_kind"
        case breakReason = "break_reason"
        case recordedAt = "recorded_at"
    }
}

struct ServerTrackPoint: Decodable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double?
    let speed: Double?
    let course: Double?
    let movementState: String?
    let stepsDelta: Int?
    let confidenceScore: Int?
    let movementKind: String?
    let breakReason: String?
    let recordedAt: String

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case horizontalAccuracy = "horizontal_accuracy"
        case speed
        case course
        case movementState = "movement_state"
        case stepsDelta = "steps_delta"
        case confidenceScore = "confidence_score"
        case movementKind = "movement_kind"
        case breakReason = "break_reason"
        case recordedAt = "recorded_at"
    }
}
