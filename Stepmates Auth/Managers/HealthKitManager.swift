//
//  HealthKitManager.swift
//  Stepmates Auth
//
//  Created by Диана on 16/03/2026.
//

import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    
    private init() {}

    func isHealthDataAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
            && HKObjectType.quantityType(forIdentifier: .stepCount) != nil
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard isHealthDataAvailable(),
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("HealthKit is not available or step type is nil")
            completion(false, nil)
            return
        }
        
        healthStore.requestAuthorization(toShare: [], read: [stepType]) { success, error in
            if let error {
                print("HealthKit authorization error:", error.localizedDescription)
            }
            
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func enableBackgroundDelivery() {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        healthStore.enableBackgroundDelivery(
            for: stepType,
            frequency: .immediate
        ) { success, error in
            if let error {
                print("HealthKit background delivery error:", error.localizedDescription)
            } else {
                print("HealthKit background delivery enabled:", success)
            }
        }
    }
    
    func fetchTodaySteps(completion: @escaping (Double) -> Void) {
        fetchSteps(from: Calendar.current.startOfDay(for: Date()), to: Date(), completion: completion)
    }

    func fetchSteps(from startDate: Date, to endDate: Date, completion: @escaping (Double) -> Void) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion(0)
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            if let error {
                print("HealthKit fetch steps error:", error.localizedDescription)
            }

            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            
            DispatchQueue.main.async {
                completion(steps)
            }
        }
        
        healthStore.execute(query)
    }
    
    func startObservingSteps(onUpdate: @escaping () -> Void) {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        if let observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
        
        observerQuery = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completionHandler, error in
            if let error {
                print("HKObserverQuery error:", error.localizedDescription)
                completionHandler()
                return
            }
            
            DispatchQueue.main.async {
                onUpdate()
            }
            
            completionHandler()
        }
        
        if let observerQuery {
            healthStore.execute(observerQuery)
        }
    }
    
    func stopObservingSteps() {
        if let observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
    }
}
