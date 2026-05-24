//
//  TrackSegmentation.swift
//  Stepmates Auth
//
//  Created by Диана on 30/04/2026.
//

import Foundation
import CoreLocation
import YandexMapsMobile

enum TrackSegmentation {
    static let maxTimeGap: TimeInterval = 5 * 60
    static let maxJumpDistance: CLLocationDistance = 120
    static let maxJumpSpeed: CLLocationSpeed = 4.5
    
    static func buildTrackSegments(from samples: [TrackSample]) -> [TrackSegment] {
        guard !samples.isEmpty else { return [] }
        
        var result: [TrackSegment] = []
        var currentSamples: [TrackSample] = [samples[0]]
        
        for index in 1..<samples.count {
            let previous = samples[index - 1]
            let current = samples[index]
            
            let previousLocation = CLLocation(
                latitude: previous.point.latitude,
                longitude: previous.point.longitude
            )
            let currentLocation = CLLocation(
                latitude: current.point.latitude,
                longitude: current.point.longitude
            )
            
            let time = current.recordedAt.timeIntervalSince(previous.recordedAt)
            let distance = currentLocation.distance(from: previousLocation)
            
            let shouldStartNewSegment: Bool
            
            if time <= 0 {
                shouldStartNewSegment = true
            } else if time > maxTimeGap {
                shouldStartNewSegment = true
            } else if shouldSeparateByContext(previous: previous, current: current) {
                shouldStartNewSegment = true
            } else {
                let derivedSpeed = distance / time
                shouldStartNewSegment = distance > maxJumpDistance && derivedSpeed > maxJumpSpeed
            }
            
            if shouldStartNewSegment {
                if let segment = makeSegment(from: currentSamples) {
                    result.append(segment)
                }
                currentSamples = [current]
            } else {
                currentSamples.append(current)
            }
        }
        
        if let segment = makeSegment(from: currentSamples) {
            result.append(segment)
        }
        
        return result
    }
}

private extension TrackSegmentation {
    static func shouldSeparateByContext(previous: TrackSample, current: TrackSample) -> Bool {
        if previous.movementKind != current.movementKind {
            return true
        }
        
        if previous.breakReason != current.breakReason {
            return true
        }
        
        if previous.quality == .poor || current.quality == .poor {
            return previous.quality != current.quality
        }
        
        return false
    }
    
    static func makeSegment(from samples: [TrackSample]) -> TrackSegment? {
        guard samples.count >= 2 else { return nil }
        
        var quality = samples.reduce(.good) { partial, sample in
            TrackQuality.worst(partial, sample.quality)
        }
        let movementKind = dominantMovementKind(from: samples)
        let breakReason = samples.first { $0.breakReason != nil }?.breakReason
        let confidenceScore = averageConfidence(from: samples)
        
        if !movementKind.isRouteDrawable || breakReason != nil {
            quality = .poor
        }
        
        return TrackSegment(
            points: samples.map(\.point),
            quality: quality,
            startedAt: samples.first!.recordedAt,
            endedAt: samples.last!.recordedAt,
            rawPoints: samples.map(\.rawPoint),
            confidenceScore: confidenceScore,
            movementKind: movementKind,
            breakReason: breakReason
        )
    }
    
    static func averageConfidence(from samples: [TrackSample]) -> Int {
        let total = samples.reduce(0) { partial, sample in
            partial + sample.confidenceScore
        }
        
        return total / max(samples.count, 1)
    }
    
    static func dominantMovementKind(from samples: [TrackSample]) -> MapMovementKind {
        let grouped = Dictionary(grouping: samples, by: \.movementKind)
        
        return grouped.max { lhs, rhs in
            lhs.value.count < rhs.value.count
        }?.key ?? .unknown
    }
}
