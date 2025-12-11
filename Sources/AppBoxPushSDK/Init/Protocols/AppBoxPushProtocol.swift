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
    func createFCMImage(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void)

    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxPushInitWithLauchOptions()
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxPushSendToken(pushYn: String, completion: @escaping (Bool, Bool) -> Void)
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxSetSegment(segment:[String: String], completion: @escaping (Bool) -> Void)
    
    // MARK: - Initialization Methods
    
    /// Firebase Client ID 초기화
    ///
    /// AppDelegate의 `application(_:didFinishLaunchingWithOptions:)`에서 호출해야 합니다.
    ///
    /// - Parameter clientID: Firebase Client ID
    @objc(initializeFirebaseClientID:)
    func initializeFirebaseClientID(clientID: String)
}
