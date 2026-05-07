//
//  AppBoxPushDelegate.swift
//  AppBoxPushSDK
//

import Foundation

@objc public protocol AppBoxPushDelegate: AnyObject {
    @objc optional func appBoxPushTokenDidUpdate(_ token: String?)
}
