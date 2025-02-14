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
}
