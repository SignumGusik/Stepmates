//
//  TrackSample.swift
//  Stepmates Auth
//
//  Created by Диана on 30/04/2026.
//

import Foundation
import YandexMapsMobile

struct TrackSample {
    let point: YMKPoint
    let rawPoint: YMKPoint
    let recordedAt: Date
    let quality: TrackQuality
    let movementState: MovementState
    let horizontalAccuracy: Double?
    let confidenceScore: Int
    let movementKind: MapMovementKind
    let breakReason: TrackBreakReason?
    
    init(
        point: YMKPoint,
        recordedAt: Date,
        quality: TrackQuality,
        movementState: MovementState,
        horizontalAccuracy: Double?,
        rawPoint: YMKPoint? = nil,
        confidenceScore: Int? = nil,
        movementKind: MapMovementKind = .unknown,
        breakReason: TrackBreakReason? = nil
    ) {
        self.point = point
        self.rawPoint = rawPoint ?? point
        self.recordedAt = recordedAt
        self.quality = quality
        self.movementState = movementState
        self.horizontalAccuracy = horizontalAccuracy
        self.confidenceScore = confidenceScore ?? TrackSample.defaultConfidenceScore(for: quality)
        self.movementKind = movementKind
        self.breakReason = breakReason
    }
}

private extension TrackSample {
    static func defaultConfidenceScore(for quality: TrackQuality) -> Int {
        switch quality {
        case .good:
            return 88
        case .weak:
            return 58
        case .poor:
            return 22
        }
    }
}
