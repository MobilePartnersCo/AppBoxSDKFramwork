//
//  AppBoxPushProtocol.swift
//  appboxpush
//
//  Created by mobilePartners on 1/24/25.
//


import Foundation
import UIKit
import UserNotifications

@objc public protocol AppBoxPushProtocol {
    /// 단독 푸시 고객사용 SDK 초기화 API입니다.
    /// AppBoxSDK의 웹뷰 런타임이나 dummy baseUrl 없이 projectId만으로 PushSDK/CoreSDK 경로를 준비합니다.
    @objc(initSDKWithProjectId:debugMode:)
    func initSDK(projectId: String, debugMode: Bool)

    /// 단독 푸시 고객사용 SDK 초기화 API입니다. debugMode 기본값은 false입니다.
    @objc(initSDKWithProjectId:)
    func initSDK(projectId: String)

    /// APNs token을 Firebase Messaging에 전달하고 FCM token 저장 흐름을 실행합니다.
    func appBoxPushApnsToken(apnsToken: Data)

    /// Notification Service Extension에서 rich push 이미지 첨부를 처리합니다.
    func createFCMImage(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void)

    /// 알림 권한 요청 public API입니다. Objective-C mixed project에서 `requestPushAuthorization:` selector로 호출됩니다.
    @objc(requestPushAuthorization:)
    func requestPushAuthorization(completion: @escaping (Bool) -> Void)

    /// 푸시 클릭 통계와 conversion metadata 저장을 처리합니다.
    /// completion overload는 1차 구현 범위에서 제공하지 않습니다.
    @objc(saveNotiClick:)
    func saveNotiClick(_ response: UNNotificationResponse)

    /// sendMessage 호환용 native wrapper입니다. 외부에서 보관한 FCM token과 push 동의값을 직접 저장합니다.
    @objc(savePushTokenWithToken:pushYn:)
    func savePushToken(token: String, pushYn: Bool)

    /// sendMessage 호환용 native wrapper입니다. SDK가 저장한 FCM token을 반환합니다.
    @objc(getPushToken)
    func getPushToken() -> String?

    /// sendMessage 호환용 helper입니다. push payload의 `param` 값을 AppBoxNotiModel로 감싸 반환합니다.
    @objc(receiveNotiModel:)
    func receiveNotiModel(_ response: UNNotificationResponse) -> AppBoxNotiModel?

    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxPushInitWithLauchOptions()
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxPushSendToken(pushYn: String, completion: @escaping (Bool, Bool) -> Void)
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxSetSegment(segment:[String: String], completion: @escaping (Bool) -> Void)

    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxPushSubscribeTopic(_ topic: String, source: String, completion: @escaping (Bool, Int, String) -> Void)

    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxPushUnsubscribeTopic(_ topic: String, source: String, completion: @escaping (Bool, Int, String) -> Void)

    // MARK: - Initialization Methods
    
    /// Firebase Client ID 초기화
    ///
    /// AppDelegate의 `application(_:didFinishLaunchingWithOptions:)`에서 호출해야 합니다.
    ///
    /// - Parameter clientID: Firebase Client ID
    @objc(initializeFirebaseClientID:)
    func initializeFirebaseClientID(clientID: String)
}
