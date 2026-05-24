//
//  TrackSmoothing.swift
//  Stepmates Auth
//
//  Created by Диана on 30/04/2026.
//

import Foundation
import YandexMapsMobile

enum TrackSmoothing {
    static func smoothSegments(_ segments: [[YMKPoint]]) -> [[YMKPoint]] {
        segments.map { smoothSegment($0) }
    }
    
    static func smoothSegment(_ segment: [YMKPoint]) -> [YMKPoint] {
        guard segment.count >= 3 else { return segment }
        
        var result: [YMKPoint] = []
        result.append(segment[0])
        
        for index in 1..<(segment.count - 1) {
            let previous = segment[index - 1]
            let current = segment[index]
            let next = segment[index + 1]
            
            let smoothedLatitude = (previous.latitude + current.latitude + next.latitude) / 3.0
            let smoothedLongitude = (previous.longitude + current.longitude + next.longitude) / 3.0
            
            result.append(
                YMKPoint(
                    latitude: smoothedLatitude,
                    longitude: smoothedLongitude
                )
            )
        }
        
        result.append(segment[segment.count - 1])
        return result
    }
}
