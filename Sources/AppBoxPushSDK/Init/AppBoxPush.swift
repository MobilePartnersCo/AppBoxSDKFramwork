//
//  AppboxPush.swift
//  appboxpush
//
//  Created by mobilePartners on 1/24/25.
//

import Foundation
@_spi(AppBoxPushSDK) import AppBoxCoreSDK

@objc(AppBoxPush)
public class AppBoxPush: NSObject {
    @objc public static let shared: AppBoxPushProtocol = AppBoxPushRepository.shared

    @_spi(AppBoxPushSDK)
    public static func configureCoreProvider(_ provider: AppBoxPushCoreProviding?) {
        AppBoxPushCoreProviderRegistry.shared.provider = provider
    }

    @objc(configureCoreProvider:)
    public static func configureCoreProviderObject(_ provider: AnyObject?) {
        configureCoreProvider(provider as? AppBoxPushCoreProviding)
    }
}
