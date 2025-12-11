//
//  AppBoxPushRepository.swift
//  appboxpush
//
//  Created by mobilePartners on 1/24/25.
//


import UIKit
@_spi(AppBoxPushSDK) import AppBoxSDK
import Firebase

class AppBoxPushRepository: NSObject, AppBoxPushProtocol {

    static let shared = AppBoxPushRepository()
    let center = UNUserNotificationCenter.current()
    
    // 초기화 중복 호출 방지 플래그
    private var isInitializing = false
    
    // Firebase Client ID 저장
   private static var firebaseClientID: String?
    
    private override init() {
        super.init()
    }
    
    func appBoxPushInitWithLauchOptions() {
        if FirebaseApp.app() != nil {
            debugLog("appBoxPushInitWithLauchOptions: Firebase 이미 초기화됨")
            return
        }
        
        if isInitializing {
            debugLog("appBoxPushInitWithLauchOptions: 초기화 진행 중")
            return
        }
        
        guard let projectId = AppBox.shared.getProjectId() else {
            return
        }
        
        isInitializing = true
        debugLog("appBoxPushInitWithLauchOptions: 초기화 시작")
        
        AppBox.shared.getPushInfo(projectId) {
 [weak self] isSuccess,
 model in
            guard let self = self else { return }
            self.isInitializing = false
            
            let workItem = DispatchWorkItem {
                if isSuccess {
                    guard let info = model else {
                        debugLog("appBoxPushInitWithLauchOptions: Firebase 정보 없음")
                        return
                    }
                    
                    let options = FirebaseOptions(
                        googleAppID: info.app_id,
                        gcmSenderID: info.sender_id
                    )
                    options.apiKey = info.api_key
                    options.projectID = info.project_id
                    // 설정된 clientID 사용
                    if let clientID = AppBoxPushRepository.firebaseClientID {
                        options.clientID = clientID
                        debugLog(
                            "appBoxPushInitWithLauchOptions: 설정된 Firebase Client ID 사용"
                        )
                    } else {
                        debugLog(
                            "appBoxPushInitWithLauchOptions: Firebase Client ID가 설정되지 않음, clientID 없이 초기화 진행"
                        )
                    }
                    
                    FirebaseApp.configure(options: options)
                    UIApplication.shared.registerForRemoteNotifications()
                    debugLog("appBoxPushInitWithLauchOptions: Firebase 초기화 완료")
                } else {
                    UIApplication.shared.registerForRemoteNotifications()
                    debugLog("appBoxPushInitWithLauchOptions: Firebase 초기화 실패")
                }
            }
            DispatchQueue.main.async(execute: workItem)
        }
    }
    
    
    private func appBoxPushRequestPermissionForNotifications(completion: @escaping (Bool) -> Void) {
        let options: UNAuthorizationOptions = [.badge, .alert, .sound]
        
        
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    //허용
                    completion(true)
                case .denied:
                    //거부
                    completion(false)
                case .notDetermined:
                    // 권한 요청 안함
                    self.center.requestAuthorization(options: options) { granted, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                debugLog("Error requesting notification authorization: \(error.localizedDescription)")
                            }

                            completion(granted)
                        }
                    }
                @unknown default:
                    //알 수없는 상태
                    completion(false)
                }
            }
        }
    }
    
    func appBoxPushApnsToken(apnsToken: Data) {
        guard let _ = FirebaseApp.app() else {
            debugLog("push init fail")
            return
        }
        
        
        Messaging.messaging().apnsToken = apnsToken
        
        self.appBoxPushRequestPermissionForNotifications { result in
            Messaging.messaging().token { token, error in
                
                let pushToken = token ?? AppBox.shared.getPushToken() ?? ""

                debugLog("save token :: \(String(describing: pushToken))")
                AppBox.shared.setPushToken(pushToken, pushYn: "")
            }
        }
    }
    
    func appBoxPushSendToken(pushYn: String, completion: @escaping (Bool, Bool) -> Void) {
        guard let _ = FirebaseApp.app() else {
            debugLog("push init fail")
            completion(false, false)
            return
        }
        if pushYn == "Y" {
            self.appBoxPushRequestPermissionForNotifications { permissionResult in
                if !permissionResult {
                    // 권한이 없으면 API 호출하지 않고 즉시 반환
                    completion(false, false)
                    return
                }
                
                // 권한이 있으면 API 호출
                Messaging.messaging().token { token, error in
                    debugLog("new Token :: \(String(describing: token))")
                    let pushToken = token ?? AppBox.shared.getPushToken() ?? ""
                    
                    AppBox.shared.setPushToken(pushToken, pushYn: pushYn) { apiSuccess in
                        completion(true, apiSuccess)
                    }
                }
            }
        } else {
            // pushYn이 "N"이면 권한 체크 없이 API만 호출
            Messaging.messaging().token { token, error in
                let pushToken = token ?? AppBox.shared.getPushToken() ?? ""
                AppBox.shared.setPushToken(pushToken, pushYn: pushYn) { apiSuccess in
                    completion(true, apiSuccess)
                }
            }
        }
    }
    
    func createFCMImage(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        AppBox.shared.setFCMImage(request, contentHandler: contentHandler)
    }
    
    func appBoxSetSegment(segment: [String : String], completion: @escaping (Bool) -> Void) {
        AppBox.shared.setSegment(segment) { success in
            completion(success)
        }
    }
    
    @objc(initializeFirebaseClientID:)
    func initializeFirebaseClientID(clientID: String) {
        guard AppBoxPushRepository.firebaseClientID == nil else {
            debugLog("AppBoxPushRepository: Firebase Client ID가 이미 초기화됨")
            return
        }
        
        AppBoxPushRepository.firebaseClientID = clientID
        debugLog("AppBoxPushRepository: Firebase Client ID 초기화 완료")
    }
}
