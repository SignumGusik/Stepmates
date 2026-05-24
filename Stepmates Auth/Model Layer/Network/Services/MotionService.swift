//
//  MotionService.swift
//  Stepmates Auth
//
//  Created by Диана on 30/04/2026.
//

import Foundation
import CoreMotion

protocol MotionServiceDelegate: AnyObject {
    func motionService(_ service: MotionService, didUpdate snapshot: MotionSnapshot)
}

final class MotionService {
    
    weak var delegate: MotionServiceDelegate?
    
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private let queue = OperationQueue()
    
    private var currentState: MovementState = .unknown
    private var confidenceHigh = false
    
    private var baselineSteps: Int?
    private var lastDeliveredSteps: Int = 0
    private var lastPedometerDate: Date?
    
    init() {
        queue.qualityOfService = .userInitiated
    }
    
    func start() {
        startActivityUpdates()
        startPedometerUpdates()
    }
    
    func stop() {
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
    }
}

private extension MotionService {
    func startActivityUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        
        activityManager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let self, let activity else { return }
            
            let state: MovementState
            if activity.automotive {
                state = .automotive
            } else if activity.cycling {
                state = .cycling
            } else if activity.running {
                state = .running
            } else if activity.walking {
                state = .walking
            } else if activity.stationary {
                state = .stationary
            } else {
                state = .unknown
            }
            
            self.currentState = state
            self.confidenceHigh = activity.confidence == .high
            self.emitSnapshot(stepsDeltaOverride: nil, cadence: nil)
        }
    }
    
    func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        
        let startDate = Date()
        lastPedometerDate = startDate
        
        pedometer.startUpdates(from: startDate) { [weak self] data, _ in
            guard let self, let data else { return }
            
            let totalSteps = data.numberOfSteps.intValue
            
            if self.baselineSteps == nil {
                self.baselineSteps = totalSteps
            }
            
            let baseline = self.baselineSteps ?? totalSteps
            let stepsDelta = max(0, totalSteps - baseline)
            
            let cadence: Double?
            if let start = self.lastPedometerDate {
                let elapsedMinutes = max(Date().timeIntervalSince(start) / 60.0, 0.0001)
                cadence = Double(stepsDelta) / elapsedMinutes
            } else {
                cadence = nil
            }
            
            self.lastDeliveredSteps = stepsDelta
            self.emitSnapshot(stepsDeltaOverride: stepsDelta, cadence: cadence)
        }
    }
    
    func emitSnapshot(stepsDeltaOverride: Int?, cadence: Double?) {
        let snapshot = MotionSnapshot(
            state: currentState,
            stepsDelta: stepsDeltaOverride ?? lastDeliveredSteps,
            cadenceStepsPerMinute: cadence,
            confidenceHigh: confidenceHigh
        )
        
        DispatchQueue.main.async {
            self.delegate?.motionService(self, didUpdate: snapshot)
        }
    }
}
