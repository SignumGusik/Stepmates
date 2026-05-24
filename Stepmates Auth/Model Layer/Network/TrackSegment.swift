//
//  TrackSegment.swift
//  Stepmates Auth
//
//  Created by Диана on 30/04/2026.
//

import Foundation
import YandexMapsMobile

struct TrackSegment {
    let points: [YMKPoint]
    let rawPoints: [YMKPoint]
    let quality: TrackQuality
    let startedAt: Date
    let endedAt: Date
    let confidenceScore: Int
    let movementKind: MapMovementKind
    let breakReason: TrackBreakReason?
    
    init(
        points: [YMKPoint],
        quality: TrackQuality,
        startedAt: Date,
        endedAt: Date,
        rawPoints: [YMKPoint]? = nil,
        confidenceScore: Int? = nil,
        movementKind: MapMovementKind = .unknown,
        breakReason: TrackBreakReason? = nil
    ) {
        self.points = points
        self.rawPoints = rawPoints ?? points
        self.quality = quality
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.confidenceScore = confidenceScore ?? TrackSegment.defaultConfidenceScore(for: quality)
        self.movementKind = movementKind
        self.breakReason = breakReason
    }
    
    var isDrawableWalkSegment: Bool {
        quality != .poor && movementKind.isRouteDrawable && breakReason == nil
    }
}

private extension TrackSegment {
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
