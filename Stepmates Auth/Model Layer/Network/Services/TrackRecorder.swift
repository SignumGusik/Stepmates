//
//  TrackRecorder.swift
//  Stepmates Auth
//
//  Created by Диана on 21/04/2026.
//

import Foundation
import CoreLocation
import YandexMapsMobile

final class TrackRecorder {
    
    private(set) var points: [YMKPoint] = []
    private(set) var samples: [TrackSample] = []
    
    private var acceptedLocations: [CLLocation] = []
    
    private let minDistanceToAppend: CLLocationDistance = 5
    private let minDistanceWhenNoFootMotion: CLLocationDistance = 10
    private let maxWalkingSpeed: CLLocationSpeed = 3.2
    private let minTurnCheckDistance: CLLocationDistance = 6
    private let suspiciousTurnAngle: Double = 120
    private let maxAcceptedAccuracy: CLLocationAccuracy = 220
    private let maxAcceptedAge: TimeInterval = 35
    private let hardRejectSpeed: CLLocationSpeed = 8.0
    
    func appendIfNeeded(_ location: CLLocation, motion: MotionSnapshot?) -> Bool {
        let confidence = LocationConfidence.evaluate(
            location: location,
            previousLocation: acceptedLocations.last,
            motion: motion
        )
        
        guard isValidCoordinate(location) else { return false }
        guard isFreshEnough(location) else { return false }
        guard isAccurateEnough(location) else { return false }
        guard isPlausibleBySpeed(location, confidence: confidence) else { return false }
        guard !isStandingNoise(location, motion: motion, confidence: confidence) else { return false }
        guard !isSuspiciousDirectionJump(location, confidence: confidence) else { return false }
        
        acceptedLocations.append(location)
        trimAcceptedLocations()
        
        let rawPoint = YMKPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        let displayPoint = displayPoint(for: rawPoint, confidence: confidence)
        
        points.append(displayPoint)
        samples.append(
            TrackSample(
                point: displayPoint,
                recordedAt: location.timestamp,
                quality: confidence.quality,
                movementState: motion?.state ?? .unknown,
                horizontalAccuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
                rawPoint: rawPoint,
                confidenceScore: confidence.score,
                movementKind: confidence.movementKind,
                breakReason: confidence.breakReason
            )
        )
        return true
    }
    
    func replace(with samples: [TrackSample]) {
        self.samples = samples
        self.points = samples.map(\.point)
        self.acceptedLocations = samples.map {
            CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: $0.rawPoint.latitude,
                    longitude: $0.rawPoint.longitude
                ),
                altitude: 0,
                horizontalAccuracy: $0.horizontalAccuracy ?? 5,
                verticalAccuracy: -1,
                timestamp: $0.recordedAt
            )
        }
        trimAcceptedLocations()
    }
    
    func clear() {
        points.removeAll()
        samples.removeAll()
        acceptedLocations.removeAll()
    }
}

private extension TrackRecorder {
    func isValidCoordinate(_ location: CLLocation) -> Bool {
        location.coordinate.latitude != 0 &&
        location.coordinate.longitude != 0 &&
        location.horizontalAccuracy >= 0
    }
    
    func isFreshEnough(_ location: CLLocation) -> Bool {
        abs(location.timestamp.timeIntervalSinceNow) <= maxAcceptedAge
    }
    
    func isAccurateEnough(_ location: CLLocation) -> Bool {
        location.horizontalAccuracy <= maxAcceptedAccuracy
    }
    
    func isPlausibleBySpeed(_ location: CLLocation, confidence: LocationConfidence) -> Bool {
        guard let last = acceptedLocations.last else { return true }
        
        let distance = location.distance(from: last)
        let time = location.timestamp.timeIntervalSince(last.timestamp)
        guard time > 0 else { return false }
        
        let derivedSpeed = distance / time
        
        let isSegmentBreak = distance > TrackSegmentation.maxJumpDistance &&
            derivedSpeed > TrackSegmentation.maxJumpSpeed

        if derivedSpeed > hardRejectSpeed &&
            !isSegmentBreak &&
            confidence.movementKind != .transport {
            return false
        }
        
        if location.speed >= 0,
           location.speed > hardRejectSpeed,
           confidence.movementKind != .transport {
            return false
        }
        
        return true
    }
    
    func isStandingNoise(
        _ location: CLLocation,
        motion: MotionSnapshot?,
        confidence: LocationConfidence
    ) -> Bool {
        guard let last = acceptedLocations.last else { return false }
        
        let distance = location.distance(from: last)
        
        if confidence.movementKind == .transport {
            return distance < 35
        }
        
        if confidence.breakReason != nil {
            return distance < 25
        }
        
        let minimumDistance = (motion?.isMovingOnFoot == true) ? minDistanceToAppend : minDistanceWhenNoFootMotion
        
        if distance < minimumDistance {
            return true
        }
        
        if distance < location.horizontalAccuracy * 0.45 {
            return true
        }
        
        if let motion {
            if motion.isStationaryLike && motion.stepsDelta == 0 && distance < 10 {
                return true
            }
            
            if !motion.isMovingOnFoot && motion.stepsDelta == 0 && distance < 10 {
                return true
            }
        }
        
        return false
    }
    
    func isSuspiciousDirectionJump(_ location: CLLocation, confidence: LocationConfidence) -> Bool {
        if confidence.breakReason != nil || confidence.movementKind == .transport {
            return false
        }
        
        guard acceptedLocations.count >= 2 else { return false }
        
        let a = acceptedLocations[acceptedLocations.count - 2]
        let b = acceptedLocations[acceptedLocations.count - 1]
        let c = location
        
        let distAB = b.distance(from: a)
        let distBC = c.distance(from: b)

        if distBC > TrackSegmentation.maxJumpDistance {
            return false
        }
        
        if distAB < minTurnCheckDistance || distBC < minTurnCheckDistance {
            return false
        }
        
        let angle = angleBetween(a: a.coordinate, b: b.coordinate, c: c.coordinate)
        
        if angle > suspiciousTurnAngle && distBC < 20 {
            return true
        }
        
        let time = c.timestamp.timeIntervalSince(b.timestamp)
        if time > 0 {
            let derivedSpeed = distBC / time
            if angle > suspiciousTurnAngle && derivedSpeed > maxWalkingSpeed {
                return true
            }
        }
        
        return false
    }
    
    func angleBetween(
        a: CLLocationCoordinate2D,
        b: CLLocationCoordinate2D,
        c: CLLocationCoordinate2D
    ) -> Double {
        let ab = vector(from: a, to: b)
        let bc = vector(from: b, to: c)
        
        let dot = ab.dx * bc.dx + ab.dy * bc.dy
        let magAB = sqrt(ab.dx * ab.dx + ab.dy * ab.dy)
        let magBC = sqrt(bc.dx * bc.dx + bc.dy * bc.dy)
        
        guard magAB > 0, magBC > 0 else { return 0 }
        
        let cosValue = max(-1.0, min(1.0, dot / (magAB * magBC)))
        return acos(cosValue) * 180 / .pi
    }
    
    func vector(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> (dx: Double, dy: Double) {
        let dx = to.longitude - from.longitude
        let dy = to.latitude - from.latitude
        return (dx, dy)
    }
    
    func displayPoint(for rawPoint: YMKPoint, confidence: LocationConfidence) -> YMKPoint {
        guard let last = samples.last?.point else { return rawPoint }
        guard confidence.quality != .good else { return rawPoint }
        guard confidence.movementKind.isRouteDrawable else { return rawPoint }
        
        let factor = confidence.quality == .weak ? 0.72 : 0.42
        
        return YMKPoint(
            latitude: last.latitude + (rawPoint.latitude - last.latitude) * factor,
            longitude: last.longitude + (rawPoint.longitude - last.longitude) * factor
        )
    }
    
    func trimAcceptedLocations() {
        if acceptedLocations.count > 6 {
            acceptedLocations.removeFirst(acceptedLocations.count - 6)
        }
    }
}
