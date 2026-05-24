//
//  MovementState.swift
//  Stepmates Auth
//
//  Created by Диана on 30/04/2026.
//

import Foundation

enum MovementState: String {
    case stationary
    case walking
    case running
    case automotive
    case cycling
    case unknown
}

struct MotionSnapshot {
    let state: MovementState
    let stepsDelta: Int
    let cadenceStepsPerMinute: Double?
    let confidenceHigh: Bool
    
    var isMovingOnFoot: Bool {
        state == .walking || state == .running
    }
    
    var isStationaryLike: Bool {
        state == .stationary
    }
    
    var isVehicleLike: Bool {
        state == .automotive || state == .cycling
    }
}
