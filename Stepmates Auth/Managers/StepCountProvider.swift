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

extension Notification.Name {
    static let stepSyncDidUpdateRecentDays = Notification.Name("stepSyncDidUpdateRecentDays")
}

final class StepSyncManager {
    static let shared = StepSyncManager()

    private let tokenStorage = AccessTokenStorage()
    private lazy var networkHandler = NetworkHandler(tokenStorage: tokenStorage)
    private var isSyncing = false

    private let todaySyncInterval: TimeInterval = 15 * 60
    private let pastDaySyncInterval: TimeInterval = 6 * 60 * 60

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {}

    func syncRecentDays(
        reason: String,
        daysBack: Int = 2,
        force: Bool = false,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard tokenStorage.get() != nil else {
            completion?(false)
            return
        }

        guard isSyncing == false else {
            completion?(false)
            return
        }

        let calendar = Calendar.current
        let dates = (0...max(0, daysBack)).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: Date())
        }

        let candidates = dates.filter { force || shouldSync(date: $0) }
        guard candidates.isEmpty == false else {
            completion?(false)
            return
        }

        isSyncing = true
        syncNext(dates: candidates, didSyncAny: false, completion: completion)
    }

    private func syncNext(
        dates: [Date],
        didSyncAny: Bool,
        completion: ((Bool) -> Void)?
    ) {
        guard let date = dates.first else {
            isSyncing = false
            if didSyncAny {
                NotificationCenter.default.post(name: .stepSyncDidUpdateRecentDays, object: nil)
            }
            completion?(didSyncAny)
            return
        }

        let remainingDates = Array(dates.dropFirst())

        StepCountProvider.shared.fetchSteps(for: date) { [weak self] snapshot in
            guard let self else { return }

            guard let snapshot, snapshot.steps > 0 else {
                self.markSyncAttempt(date: date)
                self.syncNext(dates: remainingDates, didSyncAny: didSyncAny, completion: completion)
                return
            }

            Task {
                let didSync = await self.upload(steps: snapshot.steps, date: date)

                await MainActor.run {
                    self.markSyncAttempt(date: date)

                    self.syncNext(
                        dates: remainingDates,
                        didSyncAny: didSyncAny || didSync,
                        completion: completion
                    )
                }
            }
        }
    }

    private func upload(steps: Int, date: Date) async -> Bool {
        guard let routeURL = NetworkRoutes.syncTodaySteps.url,
              let token = tokenStorage.get() else {
            return false
        }

        do {
            _ = try await networkHandler.request(
                routeURL,
                jsonDictionary: [
                    "steps": steps,
                    "date": dateFormatter.string(from: date)
                ],
                responseType: SyncTodayStepsResponse.self,
                httpMethod: NetworkRoutes.syncTodaySteps.method.rawValue,
                accessToken: token.accessToken
            )
            return true
        } catch {
            print("StepSyncManager upload error:", error.localizedDescription)
            return false
        }
    }

    private func shouldSync(date: Date) -> Bool {
        let lastSyncAt = UserDefaults.standard.object(forKey: lastSyncKey(date: date)) as? Date
        guard let lastSyncAt else { return true }

        let interval = Calendar.current.isDateInToday(date) ? todaySyncInterval : pastDaySyncInterval
        return Date().timeIntervalSince(lastSyncAt) >= interval
    }

    private func markSyncAttempt(date: Date) {
        UserDefaults.standard.set(Date(), forKey: lastSyncKey(date: date))
    }

    private func lastSyncKey(date: Date) -> String {
        let rawAccountKey = tokenStorage.get()?.refreshToken ?? "anonymous"
        let accountKey = Data(rawAccountKey.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
            .prefix(36)

        return "steps.last-sync.\(accountKey).\(dateFormatter.string(from: date))"
    }
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

    func cachedSnapshot() -> StepCountSnapshot? {
        guard let lastPublishedSource else { return nil }
        return StepCountSnapshot(steps: lastPublishedSteps, source: lastPublishedSource)
    }

    func fetchSteps(
        for date: Date,
        completion: @escaping (StepCountSnapshot?) -> Void
    ) {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = min(calendar.date(byAdding: .day, value: 1, to: startDate) ?? Date(), Date())

        fetchSteps(from: startDate, to: endDate, completion: completion)
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
        queryPedometerSteps(from: startOfDay, to: Date(), completion: completion)
    }

    func queryPedometerSteps(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Int?, Error?) -> Void
    ) {
        guard CMPedometer.isStepCountingAvailable() else {
            completion(nil, nil)
            return
        }

        pedometer.queryPedometerData(from: startDate, to: endDate) { data, error in
            DispatchQueue.main.async {
                if let data {
                    completion(max(0, data.numberOfSteps.intValue), error)
                } else {
                    completion(nil, error)
                }
            }
        }
    }

    func fetchSteps(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (StepCountSnapshot?) -> Void
    ) {
        guard startDate < endDate else {
            completion(nil)
            return
        }

        var healthResult: Int?
        var pedometerResult: Int?
        var didReceivePedometer = false

        func finishIfReady() {
            guard healthResult != nil, didReceivePedometer else { return }

            let healthSteps = healthResult ?? 0
            let pedometerSteps = pedometerResult

            if let pedometerSteps, pedometerSteps >= healthSteps {
                completion(StepCountSnapshot(steps: pedometerSteps, source: .pedometer))
            } else {
                completion(StepCountSnapshot(steps: healthSteps, source: .healthKit))
            }
        }

        if !shouldSkipHealthKit, HealthKitManager.shared.isHealthDataAvailable() {
            HealthKitManager.shared.fetchSteps(from: startDate, to: endDate) { steps in
                healthResult = max(0, Int(steps))
                finishIfReady()
            }
        } else {
            healthResult = 0
        }

        queryPedometerSteps(from: startDate, to: endDate) { steps, error in
            if let error {
                print("Historical CMPedometer steps error:", error.localizedDescription)
            }

            pedometerResult = steps
            didReceivePedometer = true
            finishIfReady()
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
