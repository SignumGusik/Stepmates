//
//  TrackQuality.swift
//  Stepmates Auth
//
//  Created by Диана on 30/04/2026.
//

import Foundation
import CoreLocation

enum TrackQuality: Int, Codable {
    case good = 0
    case weak = 1
    case poor = 2
    
    static func from(location: CLLocation) -> TrackQuality {
        LocationConfidence.evaluate(
            location: location,
            previousLocation: nil,
            motion: nil
        ).quality
    }

    static func from(score: Int) -> TrackQuality {
        if score >= 78 {
            return .good
        }

        if score >= 42 {
            return .weak
        }

        return .poor
    }
    
    static func worst(_ lhs: TrackQuality, _ rhs: TrackQuality) -> TrackQuality {
        lhs.rawValue >= rhs.rawValue ? lhs : rhs
    }
    
    var badgeText: String {
        switch self {
        case .good:
            return "точная геолокация"
        case .weak:
            return "геолокация уточняется"
        case .poor:
            return "ищем сигнал"
        }
    }
}

enum TrackBreakReason: String, Codable {
    case lostSignal = "lost_signal"
    case vehicleJump = "vehicle_jump"
    case poorAccuracy = "poor_accuracy"
    case appBackground = "app_background"
    case staleLocation = "stale_location"
    
    var eventTitle: String {
        switch self {
        case .lostSignal:
            return "сигнал пропал"
        case .vehicleJump:
            return "транспорт"
        case .poorAccuracy:
            return "неточно"
        case .appBackground:
            return "пауза"
        case .staleLocation:
            return "устарело"
        }
    }
}

enum MapMovementKind: String, Codable {
    case walking
    case stationary
    case transport
    case signalLost = "signal_lost"
    case unknown
    
    var isRouteDrawable: Bool {
        self == .walking || self == .unknown
    }
    
    var labelText: String {
        switch self {
        case .walking:
            return "идет пешком"
        case .stationary:
            return "на месте"
        case .transport:
            return "в транспорте"
        case .signalLost:
            return "сигнал потерян"
        case .unknown:
            return "движение уточняется"
        }
    }

    static func fromLiveValue(_ rawValue: String?) -> MapMovementKind {
        guard let rawValue else { return .unknown }

        switch rawValue {
        case "walking", "running":
            return .walking
        case "automotive", "cycling", "transport":
            return .transport
        case "stationary":
            return .stationary
        case "signal_lost":
            return .signalLost
        default:
            return MapMovementKind(rawValue: rawValue) ?? .unknown
        }
    }
}

struct LocationConfidence {
    let score: Int
    let quality: TrackQuality
    let movementKind: MapMovementKind
    let breakReason: TrackBreakReason?
    
    static func evaluate(
        location: CLLocation,
        previousLocation: CLLocation?,
        motion: MotionSnapshot?
    ) -> LocationConfidence {
        let accuracy = location.horizontalAccuracy
        let age = abs(location.timestamp.timeIntervalSinceNow)
        let speed = location.speed
        
        var score = 100
        var breakReason: TrackBreakReason?
        
        if accuracy < 0 {
            score -= 80
            breakReason = .lostSignal
        } else if accuracy <= 12 {
            score -= 0
        } else if accuracy <= 20 {
            score -= 8
        } else if accuracy <= 45 {
            score -= 22
        } else if accuracy <= 100 {
            score -= 48
            breakReason = .poorAccuracy
        } else {
            score -= 68
            breakReason = .poorAccuracy
        }
        
        if age <= 5 {
            score -= 0
        } else if age <= 15 {
            score -= 10
        } else if age <= 30 {
            score -= 24
            breakReason = breakReason ?? .staleLocation
        } else {
            score -= 46
            breakReason = .staleLocation
        }
        
        if let previousLocation {
            let time = location.timestamp.timeIntervalSince(previousLocation.timestamp)
            
            if time > 5 * 60 {
                score -= 22
                breakReason = .appBackground
            } else if time > 0 {
                let distance = location.distance(from: previousLocation)
                let derivedSpeed = distance / time
                
                if distance > TrackSegmentation.maxJumpDistance &&
                    derivedSpeed > TrackSegmentation.maxJumpSpeed {
                    score -= 28
                    breakReason = .vehicleJump
                }
                
                if derivedSpeed > 14 {
                    score -= 18
                    breakReason = breakReason ?? .vehicleJump
                }
            }
        }
        
        if speed >= 0 {
            if speed > 13 {
                score -= 18
                breakReason = breakReason ?? .vehicleJump
            } else if speed > 7 {
                score -= 8
            }
        }
        
        if let motion {
            if motion.confidenceHigh {
                score += 4
            }
            
            if motion.isMovingOnFoot && motion.stepsDelta > 0 {
                score += 5
            }
            
            if motion.isStationaryLike && motion.stepsDelta == 0 && speed > 2 {
                score -= 14
            }
        }
        
        score = max(0, min(100, score))
        let quality = TrackQuality.from(score: score)
        let movementKind = movementKind(
            location: location,
            motion: motion,
            score: score,
            breakReason: breakReason
        )
        
        return LocationConfidence(
            score: score,
            quality: quality,
            movementKind: movementKind,
            breakReason: adjustedBreakReason(
                breakReason,
                quality: quality,
                movementKind: movementKind
            )
        )
    }
}

private extension LocationConfidence {
    static func movementKind(
        location: CLLocation,
        motion: MotionSnapshot?,
        score: Int,
        breakReason: TrackBreakReason?
    ) -> MapMovementKind {
        if score < 28 || breakReason == .lostSignal || breakReason == .staleLocation {
            return .signalLost
        }
        
        if motion?.isVehicleLike == true || (location.speed >= 0 && location.speed > 7) {
            return .transport
        }
        
        if motion?.isStationaryLike == true {
            return .stationary
        }
        
        if motion?.isMovingOnFoot == true || (motion?.stepsDelta ?? 0) > 0 {
            return .walking
        }
        
        return .unknown
    }
    
    static func adjustedBreakReason(
        _ reason: TrackBreakReason?,
        quality: TrackQuality,
        movementKind: MapMovementKind
    ) -> TrackBreakReason? {
        if movementKind == .transport {
            return reason ?? .vehicleJump
        }
        
        if movementKind == .signalLost {
            return reason ?? .lostSignal
        }
        
        if quality == .poor {
            return reason ?? .poorAccuracy
        }
        
        return reason
    }
}
