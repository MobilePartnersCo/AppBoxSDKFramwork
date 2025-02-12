//
//  AppboxPush.swift
//  appboxpush
//
//  Created by mobilePartners on 1/24/25.
//

import Foundation

@objc public class AppBoxPush: NSObject {
    @objc public static let shared: AppBoxPushProtocol = AppBoxPushRepository.shared
}
