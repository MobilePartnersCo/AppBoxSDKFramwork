//
//  File.swift
//  
//
//  Created by mobilePartners on 2/11/25.
//

import Foundation
import HealthKit

@objc public enum HealthType: Int {
    case step
}

@objc public protocol AppBoxHealthProtocol {
    
    func requestAuthorization(readType: Set<HKObjectType>, completion: @escaping (Bool, Error?) -> Void)
    func requestAuthorization(readType: Set<HKObjectType>, writeType: Set<HKSampleType>, completion: @escaping (Bool, Error?) -> Void)
    
    func getQuantityType(healthType: HealthType) -> HKObjectType?
    func fetchStep(time: Date, completion: @escaping (Double) -> Void)
    
    @objc dynamic
    func fetchStepsForPeriod(startDate: Date, numberOfDays: Int, completion: @escaping ([String: Double], Bool) -> Void)
    
}
