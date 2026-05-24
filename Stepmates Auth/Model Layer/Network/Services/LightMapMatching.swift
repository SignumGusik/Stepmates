//
//  LightMapMatching.swift
//  Stepmates Auth
//
//  Created by Диана on 30/04/2026.
//

import Foundation
import CoreLocation
import YandexMapsMobile

enum LightMapMatching {
    
    static func matchSegments(_ segments: [[YMKPoint]]) -> [[YMKPoint]] {
        segments.map { matchSegment($0) }
    }
    
    static func matchSegment(_ segment: [YMKPoint]) -> [YMKPoint] {
        matchSegment(
            segment,
            quality: .good,
            confidenceScore: 100,
            movementKind: .walking
        )
    }
    
    static func matchSegment(
        _ segment: [YMKPoint],
        quality: TrackQuality,
        confidenceScore: Int,
        movementKind: MapMovementKind
    ) -> [YMKPoint] {
        guard quality == .good else { return segment }
        guard confidenceScore >= 72 else { return segment }
        guard movementKind == .walking || movementKind == .unknown else { return segment }
        guard segment.count >= 3 else { return segment }
        
        var result = segment
        
        for index in 1..<(segment.count - 1) {
            let previous = result[index - 1]
            let current = result[index]
            let next = result[index + 1]
            
            let distPrevCurrent = distance(from: previous, to: current)
            let distCurrentNext = distance(from: current, to: next)

            guard distPrevCurrent <= 35, distCurrentNext <= 35 else { continue }
            
            let angle = turnAngle(previous: previous, current: current, next: next)
            guard angle <= 18 else { continue }
            let projected = project(point: current, ontoLineFrom: previous, to: next)
            
            let correctionDistance = distance(from: current, to: projected)
            guard correctionDistance >= 1.5, correctionDistance <= 12 else { continue }
            
            let corrected = blend(from: current, to: projected, factor: 0.55)
            result[index] = corrected
        }
        
        return result
    }
}

private extension LightMapMatching {
    static func distance(from a: YMKPoint, to b: YMKPoint) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
    
    static func turnAngle(previous: YMKPoint, current: YMKPoint, next: YMKPoint) -> Double {
        let ab = vector(from: previous, to: current)
        let bc = vector(from: current, to: next)
        
        let dot = ab.dx * bc.dx + ab.dy * bc.dy
        let magAB = sqrt(ab.dx * ab.dx + ab.dy * ab.dy)
        let magBC = sqrt(bc.dx * bc.dx + bc.dy * bc.dy)
        
        guard magAB > 0, magBC > 0 else { return 180 }
        
        let cosValue = max(-1.0, min(1.0, dot / (magAB * magBC)))
        return acos(cosValue) * 180 / .pi
    }
    
    static func vector(from: YMKPoint, to: YMKPoint) -> (dx: Double, dy: Double) {
        let dx = to.longitude - from.longitude
        let dy = to.latitude - from.latitude
        return (dx, dy)
    }
    
    static func project(point p: YMKPoint, ontoLineFrom a: YMKPoint, to b: YMKPoint) -> YMKPoint {
        let apx = p.longitude - a.longitude
        let apy = p.latitude - a.latitude
        
        let abx = b.longitude - a.longitude
        let aby = b.latitude - a.latitude
        
        let ab2 = abx * abx + aby * aby
        guard ab2 > 0 else { return p }
        
        let t = max(0.0, min(1.0, (apx * abx + apy * aby) / ab2))
        
        return YMKPoint(
            latitude: a.latitude + aby * t,
            longitude: a.longitude + abx * t
        )
    }
    
    static func blend(from original: YMKPoint, to target: YMKPoint, factor: Double) -> YMKPoint {
        let k = max(0.0, min(1.0, factor))
        
        return YMKPoint(
            latitude: original.latitude + (target.latitude - original.latitude) * k,
            longitude: original.longitude + (target.longitude - original.longitude) * k
        )
    }
}
