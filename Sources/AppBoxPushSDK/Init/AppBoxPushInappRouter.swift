//
//  AppBoxPushInappRouter.swift
//  AppBoxPushSDK
//

import Foundation
@_spi(AppBoxPushSDK) import AppBoxCoreSDK

enum AppBoxPushInappRouter {
    typealias Logger = (String) -> Void

    @discardableResult
    static func routePushClickIfNeeded(
        userInfo: [AnyHashable: Any],
        logger: Logger? = nil
    ) -> Bool {
        guard pushPayloadString(userInfo["touchOpenType"])?.lowercased() == "inapp" else {
            return false
        }

        guard let handler = AppBoxInappMessagePushHandlerRegistry.shared.handler else {
            logger?("routeInappPushClickIfNeeded: inapp handler is not configured")
            return false
        }

        return handler.handlePushClick(userInfo: userInfo)
    }

    @discardableResult
    static func routeSilentPushIfNeeded(
        userInfo: [AnyHashable: Any],
        logger: Logger? = nil
    ) -> Bool {
        guard let handler = AppBoxInappMessagePushHandlerRegistry.shared.handler else {
            logger?("routeInappSilentPushIfNeeded: inapp handler is not configured")
            return false
        }

        return handler.handleSilentPush(userInfo: userInfo)
    }

    private static func pushPayloadString(_ value: Any?) -> String? {
        let rawValue: String?
        switch value {
        case let string as String:
            rawValue = string
        case let number as NSNumber:
            rawValue = number.stringValue
        default:
            rawValue = nil
        }

        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}
