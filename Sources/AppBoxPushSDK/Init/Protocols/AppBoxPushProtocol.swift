//
//  AppBoxPushProtocol.swift
//  appboxpush
//
//  Created by mobilePartners on 1/24/25.
//


import Foundation
import UIKit

@objc public protocol AppBoxPushProtocol {
    func appBoxPushInitWithLauchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?, projectId: String)
    func appBoxPushRequestPermissionForNotifications(completion: @escaping (Bool) -> Void)
    func appBoxPushApnsToken(apnsToken: Data)

    
    @objc dynamic
    func appBoxPushSendToken(pushYn: String, completion: @escaping (Bool) -> Void)
}
