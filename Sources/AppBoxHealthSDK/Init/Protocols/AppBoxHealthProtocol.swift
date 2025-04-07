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
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic
    func fetchStepsForPeriod(startDate: Date, numberOfDays: Int, completion: @escaping ([[String : Any]], Bool) -> Void)
    
}
