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
    @objc dynamic
    func fetchStepsForPeriod(startDate: Date, numberOfDays: Int, completion: @escaping ([String: Double], Bool) -> Void)
    
}
