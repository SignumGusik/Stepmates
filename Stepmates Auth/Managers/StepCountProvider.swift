//
//  StepCountProvider.swift
//  Stepmates Auth
//
//  Created by Codex on 24/05/2026.
//

import CoreMotion
import Foundation

enum StepCountSource: Equatable {
    case healthKit
    case pedometer
}

struct StepCountSnapshot {
    let steps: Int
    let source: StepCountSource
}

final class StepCountProvider {
    static let shared = StepCountProvider()

    private let pedometer = CMPedometer()
    private var onUpdate: ((StepCountSnapshot) -> Void)?
    private var onUnavailable: ((String) -> Void)?
    private var lastHealthKitError: Error?
    private var lastPedometerSteps = 0
    private var lastPublishedSteps = 0
    private var lastPublishedSource: StepCountSource?
    private var isPedometerRunning = false
    private var livePedometerStartedAt: Date?
    private var canUseHealthKit = false

    private init() {}

    func start(
        onUpdate: @escaping (StepCountSnapshot) -> Void,
        onUnavailable: @escaping (String) -> Void
    ) {
        self.onUpdate = onUpdate
        self.onUnavailable = onUnavailable
        lastPublishedSource = nil

        requestHealthKitOrFallbackToPedometer()
    }

    func refresh() {
        if shouldSkipHealthKit {
            refreshPedometerOnly()
            return
        }

        if HealthKitManager.shared.isHealthDataAvailable() {
            refreshHealthKitThenPedometer()
            return
        }

        refreshPedometerOnly()
    }

    func stop() {
        HealthKitManager.shared.stopObservingSteps()
        pedometer.stopUpdates()
        isPedometerRunning = false
        livePedometerStartedAt = nil
        onUpdate = nil
        onUnavailable = nil
    }
}

private extension StepCountProvider {
    var shouldSkipHealthKit: Bool {
        lastHealthKitError?.localizedDescription.contains("com.apple.developer.healthkit") == true
    }

    func requestHealthKitOrFallbackToPedometer() {
        if shouldSkipHealthKit {
            canUseHealthKit = false
            startPedometerFallback()
            return
        }

        guard HealthKitManager.shared.isHealthDataAvailable() else {
            canUseHealthKit = false
            startPedometerFallback()
            return
        }

        HealthKitManager.shared.requestAuthorization { [weak self] success, error in
            guard let self else { return }

            if success {
                self.canUseHealthKit = true
                self.lastHealthKitError = nil
                HealthKitManager.shared.enableBackgroundDelivery()
                HealthKitManager.shared.startObservingSteps { [weak self] in
                    self?.refreshHealthKitThenPedometer()
                }
                self.refreshHealthKitThenPedometer()
            } else {
                self.canUseHealthKit = false
                self.lastHealthKitError = error
                self.startPedometerFallback()
            }
        }
    }

    func startPedometerFallback() {
        refreshPedometerOnly(startLiveUpdates: true)
    }

    func startPedometerUpdates(baselineSteps: Int) {
        guard CMPedometer.isStepCountingAvailable() else {
            publishUnavailable("Шаги недоступны на этом устройстве")
            return
        }

        guard isPedometerRunning == false else {
            return
        }

        isPedometerRunning = true
        let startDate = Date()
        livePedometerStartedAt = startDate

        pedometer.startUpdates(from: startDate) { [weak self] data, error in
            guard let self else { return }

            if let error {
                self.publishPedometerError(error)
                return
            }

            guard let data else { return }

            if let livePedometerStartedAt,
               Calendar.current.isDateInToday(livePedometerStartedAt) == false {
                self.pedometer.stopUpdates()
                self.isPedometerRunning = false
                self.livePedometerStartedAt = nil
                self.refreshPedometerOnly(startLiveUpdates: true)
                return
            }

            let steps = max(0, baselineSteps + data.numberOfSteps.intValue)
            self.lastPedometerSteps = steps

            if self.canUseHealthKit, steps < self.lastPublishedSteps {
                return
            }

            self.publish(steps: steps, source: .pedometer)
        }
    }

    func refreshHealthKitThenPedometer() {
        HealthKitManager.shared.fetchTodaySteps { [weak self] healthStepsValue in
            guard let self else { return }

            let healthSteps = max(0, Int(healthStepsValue))

            self.queryPedometerSteps { pedometerSteps, _ in
                let fallbackSteps = pedometerSteps ?? self.lastPedometerSteps

                if fallbackSteps > healthSteps {
                    self.lastPedometerSteps = fallbackSteps
                    self.publish(steps: fallbackSteps, source: .pedometer)
                } else {
                    self.publish(steps: healthSteps, source: .healthKit)
                }
            }
        }
    }

    func refreshPedometerOnly(startLiveUpdates: Bool = false) {
        queryPedometerSteps { [weak self] steps, error in
            guard let self else { return }

            if let steps {
                self.lastPedometerSteps = steps
                self.publish(steps: steps, source: .pedometer)

                if startLiveUpdates {
                    self.startPedometerUpdates(baselineSteps: steps)
                }

                return
            }

            if let error {
                self.publishPedometerError(error)
            } else {
                self.publishUnavailable("Шаги недоступны на этом устройстве")
            }
        }
    }

    func queryPedometerSteps(completion: @escaping (Int?, Error?) -> Void) {
        guard CMPedometer.isStepCountingAvailable() else {
            completion(nil, nil)
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())

        pedometer.queryPedometerData(from: startOfDay, to: Date()) { data, error in
            DispatchQueue.main.async {
                if let data {
                    completion(max(0, data.numberOfSteps.intValue), error)
                } else {
                    completion(nil, error)
                }
            }
        }
    }

    func publish(steps: Int, source: StepCountSource) {
        guard steps != lastPublishedSteps || source != lastPublishedSource else {
            return
        }

        lastPublishedSteps = steps
        lastPublishedSource = source

        DispatchQueue.main.async {
            self.onUpdate?(StepCountSnapshot(steps: steps, source: source))
        }
    }

    func publishUnavailable(_ message: String) {
        DispatchQueue.main.async {
            self.onUnavailable?(message)
        }
    }

    func publishPedometerError(_ error: Error) {
        if canUseHealthKit || lastPublishedSource != nil {
            print("CMPedometer steps error:", error.localizedDescription)
            return
        }

        let healthHint: String

        if let lastHealthKitError,
           lastHealthKitError.localizedDescription.contains("com.apple.developer.healthkit") {
            healthHint = "HealthKit недоступен из-за подписи IPA, а CMPedometer тоже не смог прочитать шаги."
        } else {
            healthHint = "Не удалось прочитать шаги через CMPedometer."
        }

        publishUnavailable("\(healthHint) Проверьте доступ «Движение и фитнес» в настройках.")
        print("CMPedometer steps error:", error.localizedDescription)
    }
}
