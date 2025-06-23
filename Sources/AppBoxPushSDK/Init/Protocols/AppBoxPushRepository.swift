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
    
    private override init() {}
    
    func appBoxPushInitWithLauchOptions() {
        guard let projectId = AppBox.shared.getProjectId() else { return }
        
        
        if let _ = FirebaseApp.app() {
            UIApplication.shared.registerForRemoteNotifications()
            debugLog("push init success")
            
        } else {
            AppBox.shared.getPushInfo(projectId) { [weak self] isSuccess, model in
                DispatchQueue.main.async {
                    if isSuccess {
                        guard let info = model else {
                            return
                        }
                        
                        let options = FirebaseOptions(
                            googleAppID: info.app_id,
                            gcmSenderID: info.sender_id
                        )
                        options.apiKey = info.api_key
                        options.projectID = info.project_id
                        
                        FirebaseApp.configure(options: options)
                        UIApplication.shared.registerForRemoteNotifications()
                    } else {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
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
    
    func appBoxPushSendToken(pushYn: String, completion: @escaping (Bool) -> Void) {
        guard let _ = FirebaseApp.app() else {
            debugLog("push init fail")
            completion(false)
            return
        }
        if pushYn == "Y" {
            self.appBoxPushRequestPermissionForNotifications { result in
                Messaging.messaging().token { token, error in
                    debugLog("new Token :: \(String(describing: token))")
                    let pushToken = token ?? AppBox.shared.getPushToken() ?? ""
                    
                    AppBox.shared.setPushToken(pushToken, pushYn: pushYn) { success in
                        if result {
                            completion(success)
                        } else {
                            completion(false)
                        }
                    }
                }
            }
        } else {
            Messaging.messaging().token { token, error in
                let pushToken = token ?? AppBox.shared.getPushToken() ?? ""
                AppBox.shared.setPushToken(pushToken, pushYn: pushYn) { success in
                    completion(success)
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
}
