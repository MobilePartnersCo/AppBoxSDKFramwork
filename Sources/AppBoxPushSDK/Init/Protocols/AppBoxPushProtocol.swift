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
    /// 푸시 토큰 갱신 이벤트를 전달받기 위한 delegate입니다.
    var delegate: AppBoxPushDelegate? { get set }

    /// SDK를 초기화하고, 권한 요청/APNS 자동 등록 여부와 초기화 결과를 함께 전달합니다.
    @objc(initSDKWithProjectId:debugMode:autoRegisterForAPNS:completion:)
    func initSDK(
        projectId: String?,
        debugMode: Bool,
        autoRegisterForAPNS: Bool,
        completion: ((_ result: AppBoxNotiResultModel?, _ error: NSError?, _ pushPermissionGranted: NSNumber?) -> Void)?
    )

    /// SDK를 초기화하고 초기화 결과를 전달합니다. autoRegisterForAPNS 기본값은 true입니다.
    @objc(initSDKWithProjectId:debugMode:completion:)
    func initSDK(
        projectId: String?,
        debugMode: Bool,
        completion: ((_ result: AppBoxNotiResultModel?, _ error: NSError?, _ pushPermissionGranted: NSNumber?) -> Void)?
    )

    /// SDK를 초기화하고 초기화 결과를 전달합니다. debugMode 기본값은 false이고 autoRegisterForAPNS 기본값은 true입니다.
    @objc(initSDKWithProjectId:completion:)
    func initSDK(
        projectId: String?,
        completion: ((_ result: AppBoxNotiResultModel?, _ error: NSError?, _ pushPermissionGranted: NSNumber?) -> Void)?
    )

    /// 단독 푸시 고객사용 SDK 초기화 API입니다.
    /// AppBoxSDK의 웹뷰 런타임이나 dummy baseUrl 없이 projectId만으로 PushSDK/CoreSDK 경로를 준비합니다.
    @objc(initSDKWithProjectId:debugMode:)
    func initSDK(projectId: String?, debugMode: Bool)

    /// 단독 푸시 고객사용 SDK 초기화 API입니다. debugMode 기본값은 false입니다.
    @objc(initSDKWithProjectId:)
    func initSDK(projectId: String?)

    /// APNs token을 Firebase Messaging에 전달하고 FCM token 저장 흐름을 실행합니다.
    @objc(appBoxPushApnsTokenWithApnsToken:)
    func appBoxPushApnsToken(apnsToken: Data)

    /// APNs device token을 Firebase Messaging에 전달하고 FCM token 저장 결과를 반환합니다.
    @objc(applicationDidRegisterForRemoteNotificationsWithDeviceToken:completion:)
    func application(
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data,
        completion: ((_ result: AppBoxNotiResultModel?, _ error: NSError?) -> Void)?
    )

    /// APNs device token을 Firebase Messaging에 전달하고 FCM token 저장 흐름을 실행합니다.
    @objc(applicationDidRegisterForRemoteNotificationsWithDeviceToken:)
    func application(didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)

    /// Notification Service Extension에서 rich push 이미지 첨부를 처리합니다.
    func createFCMImage(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void)

    /// Notification Service Extension에서 수신한 푸시 payload를 App Group queue에 저장합니다.
    @objc(recordNotificationReceived:)
    func recordNotificationReceived(_ request: UNNotificationRequest)

    /// App Group queue에 저장된 수신 푸시 payload를 앱 CoreData 저장소로 import합니다.
    @objc(importReceivedNotifications)
    func importReceivedNotifications()

    /// 기본 `group.<mainBundleId>` App Group 추론이 맞지 않는 앱에서 override 값을 설정합니다.
    @objc(configureAppGroupIdentifier:)
    func configureAppGroupIdentifier(_ identifier: String?)

    /// 알림 권한 요청 public API입니다. Objective-C mixed project에서 `requestPushAuthorization:` selector로 호출됩니다.
    @objc(requestPushAuthorization:)
    func requestPushAuthorization(completion: @escaping (Bool) -> Void)

    /// 푸시 클릭 통계와 conversion metadata 저장을 처리합니다.
    /// completion overload는 1차 구현 범위에서 제공하지 않습니다.
    @objc(saveNotiClick:)
    func saveNotiClick(_ response: UNNotificationResponse)

    /// 외부에서 보관한 FCM token과 push 동의값을 직접 저장합니다.
    @objc(savePushTokenWithToken:pushYn:)
    func savePushToken(token: String, pushYn: Bool)

    /// 외부에서 보관한 FCM token과 push 동의값을 저장하고 결과를 반환합니다.
    @objc(savePushTokenWithToken:pushYn:completion:)
    func savePushToken(
        token: String,
        pushYn: Bool,
        completion: ((_ result: AppBoxNotiResultModel?, _ error: NSError?) -> Void)?
    )

    /// SDK가 저장한 FCM token을 반환합니다.
    @objc(getPushToken)
    func getPushToken() -> String?

    /// push payload의 `param` 값을 AppBoxNotiModel로 감싸 반환합니다.
    @objc(receiveNotiModel:)
    func receiveNotiModel(_ response: UNNotificationResponse) -> AppBoxNotiModel?

    /// 사용자 segment 값을 저장하고 결과를 반환합니다.
    @objc(saveSegmentWithSegment:completion:)
    func saveSegment(
        segment: [String: String],
        completion: ((_ result: AppBoxNotiResultModel?, _ error: NSError?) -> Void)?
    )

    /// 사용자 segment 값을 저장합니다.
    @objc(saveSegmentWithSegment:)
    func saveSegment(segment: [String: String])

    /// conversion code 기준으로 전환을 추적하고 결과를 반환합니다.
    @objc(trackingConversionWithConversionCode:completion:)
    func trackingConversion(
        conversionCode: String,
        completion: ((_ success: Bool, _ error: NSError?) -> Void)?
    )

    /// conversion code 기준으로 전환을 추적합니다.
    @objc(trackingConversionWithConversionCode:)
    func trackingConversion(conversionCode: String)

    /// FCM topic을 구독하고 결과를 반환합니다.
    @objc(subscribeToTopic:completion:)
    func subscribeToTopic(
        _ topic: String,
        completion: ((_ success: Bool, _ error: NSError?) -> Void)?
    )

    /// FCM topic을 구독합니다.
    @objc(subscribeToTopic:)
    func subscribeToTopic(_ topic: String)

    /// FCM topic 구독을 해제하고 결과를 반환합니다.
    @objc(unsubscribeFromTopic:completion:)
    func unsubscribeFromTopic(
        _ topic: String,
        completion: ((_ success: Bool, _ error: NSError?) -> Void)?
    )

    /// FCM topic 구독을 해제합니다.
    @objc(unsubscribeFromTopic:)
    func unsubscribeFromTopic(_ topic: String)

    
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
