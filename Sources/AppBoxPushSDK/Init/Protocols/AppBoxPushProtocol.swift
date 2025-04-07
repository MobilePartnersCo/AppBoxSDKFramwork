//
//  AppBoxPushProtocol.swift
//  appboxpush
//
//  Created by mobilePartners on 1/24/25.
//


import Foundation
import UIKit

@objc public protocol AppBoxPushProtocol {
    func appBoxPushApnsToken(apnsToken: Data)

    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxPushInitWithLauchOptions()
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxPushSendToken(pushYn: String, completion: @escaping (Bool) -> Void)
}
