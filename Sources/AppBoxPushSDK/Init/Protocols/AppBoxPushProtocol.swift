//
//  AppBoxPushProtocol.swift
//  appboxpush
//
//  Created by mobilePartners on 1/24/25.
//

import UIKit

@objc public protocol AppBoxPushProtocol {
    func appBoxPushInitWithLauchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
    func appBoxPushInitWithLauchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?, requestPerMissionOnLauch: Bool)
    func appBoxPushRequestPermissionForNotifications(completion: @escaping (Bool) -> Void)
}
