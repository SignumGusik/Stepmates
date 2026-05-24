//
//  TrackSimplification.swift
//  Stepmates Auth
//
//  Created by Диана on 30/04/2026.
//

import Foundation
import CoreLocation
import YandexMapsMobile

enum TrackSimplification {
    
    // Для отрисовки маршрута
    static func simplifySegments(
        _ segments: [[YMKPoint]],
        minimumDistance: CLLocationDistance = 10
    ) -> [[YMKPoint]] {
        segments.map { simplifySegment($0, minimumDistance: minimumDistance) }
    }
    
    static func simplifySegment(
        _ segment: [YMKPoint],
        minimumDistance: CLLocationDistance = 10
    ) -> [YMKPoint] {
        guard segment.count >= 3 else { return segment }
        
        var result: [YMKPoint] = []
        result.append(segment[0])
        
        var lastKept = segment[0]
        
        for index in 1..<(segment.count - 1) {
            let current = segment[index]
            let next = segment[index + 1]
            
            let lastLocation = CLLocation(latitude: lastKept.latitude, longitude: lastKept.longitude)
            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            
            let distance = currentLocation.distance(from: lastLocation)
            
            // Если точка слишком близко к уже сохраненной — пропускаем,
            // но оставим ее, если это заметный поворот
            if distance < minimumDistance {
                let angle = turnAngle(
                    previous: lastKept,
                    current: current,
                    next: next
                )
                
                if angle > 28 {
                    result.append(current)
                    lastKept = current
                }
                
                continue
            }
            
            result.append(current)
            lastKept = current
        }
        
        result.append(segment[segment.count - 1])
        return result
    }
    
    // Для очереди на сервер: не слать почти одинаковые точки
    static func shouldAppendToUploadQueue(
        newPoint: TrackPointPayload,
        lastPoint: TrackPointPayload?,
        minimumDistance: CLLocationDistance = 8
    ) -> Bool {
        guard let lastPoint else { return true }
        
        let lastLocation = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
        let newLocation = CLLocation(latitude: newPoint.latitude, longitude: newPoint.longitude)
        
        return newLocation.distance(from: lastLocation) >= minimumDistance
    }
}

private extension TrackSimplification {
    static func turnAngle(previous: YMKPoint, current: YMKPoint, next: YMKPoint) -> Double {
        let ab = vector(from: previous, to: current)
        let bc = vector(from: current, to: next)
        
        let dot = ab.dx * bc.dx + ab.dy * bc.dy
        let magAB = sqrt(ab.dx * ab.dx + ab.dy * ab.dy)
        let magBC = sqrt(bc.dx * bc.dx + bc.dy * bc.dy)
        
        guard magAB > 0, magBC > 0 else { return 0 }
        
        let cosValue = max(-1.0, min(1.0, dot / (magAB * magBC)))
        return acos(cosValue) * 180 / .pi
    }
    
    static func vector(from: YMKPoint, to: YMKPoint) -> (dx: Double, dy: Double) {
        let dx = to.longitude - from.longitude
        let dy = to.latitude - from.latitude
        return (dx, dy)
    }
}
