//
//  File.swift
//  
//
//  Created by mobilePartners on 2/11/25.
//

import Foundation
import HealthKit

class AppBoxHealthRepository: NSObject, AppBoxHealthProtocol {
    static let shared = AppBoxHealthRepository()
    let healthStore = HKHealthStore()
    
    func requestAuthorization(readType: Set<HKObjectType>, completion: @escaping (Bool, (any Error)?) -> Void) {
        requestAuthorization(readType: readType, writeType: [], completion: completion)
    }
    
    func requestAuthorization(readType: Set<HKObjectType>, writeType: Set<HKSampleType>, completion: @escaping (Bool, (any Error)?) -> Void) {
        
        guard HKHealthStore.isHealthDataAvailable() else {
            debugLog("HealthKit not used")
            completion(false, NSError(domain: "com.apple.HealthKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "헬스데이터를 가져올 수 없습니다."]))
            return
        }
        
        
        healthStore.requestAuthorization(toShare: writeType, read: readType) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func getQuantityType(healthType: HealthType) -> HKObjectType? {
        if healthType == .step {
            guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                return nil
            }
            
            return type
        }
        
        return nil
    }
    
    func fetchStep(time: Date, completion: @escaping (Double) -> Void) {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            debugLog("Step Count Type is unavailable")
            return
        }
        
        let now = time
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: stepCountType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, results, error in
            guard error == nil else {
                debugLog("Error fetching steps: \(error!.localizedDescription)")
                completion(0.0)
                return
            }
            
            let totalSteps = results?
                    .compactMap { $0 as? HKQuantitySample }
                    .filter { !$0.sourceRevision.source.name.contains("Watch") }
                    .reduce(0) { $0 + $1.quantity.doubleValue(for: HKUnit.count()) } ?? 0

            DispatchQueue.main.async {
                completion(totalSteps)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchStepsForPeriod(startDate: Date, numberOfDays: Int, completion: @escaping ([String : Double], Bool) -> Void) {
        
        guard let stepsType = getQuantityType(healthType: .step) else {
            completion([:], false)
            return
        }
        
        requestAuthorization(readType: [stepsType]) {
            success, error in
            if success {
                debugLog("permission granted")
                
                var stepsData: [String: Double] = [:]
                let group = DispatchGroup()
                
                for i in 0..<numberOfDays {
                    let date = Calendar.current.date(byAdding: .day, value: -i, to: startDate)!
                    group.enter()
                    
                    self.fetchStep(time: date) { steps in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        let dateString = formatter.string(from: date)
         
                        stepsData[dateString] = steps
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    completion(stepsData, true)
                }
            } else {
                completion([:], false)
            }
        }
    }
}
