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
    
    func appBoxPushInitWithLauchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey : Any]?, projectId: String) {
        AppBox.shared.setProjectId(projectId)
        
        AppBox.shared.getPushInfo(projectId) { [weak self] isSuccess, model in
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
                
                DispatchQueue.main.async {
                    FirebaseApp.configure(options: options)
                    
                    Messaging.messaging().delegate = self
                    self?.center.delegate = self
                    
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    
    func appBoxPushRequestPermissionForNotifications(completion: @escaping (Bool) -> Void) {
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
        Messaging.messaging().apnsToken = apnsToken
        
        self.appBoxPushRequestPermissionForNotifications { result in
            if result {
                Messaging.messaging().token { token, error in
                    debugLog("new Token :: \(String(describing: token))")
                    guard let pushToken = token else {
                        return
                    }
                    
                    if let oldToken = AppBox.shared.getPushToken() {
                        if oldToken != pushToken {
                            debugLog("not same save token :: \(String(describing: pushToken))")
                            AppBox.shared.setPushToken(pushToken, pushYn: "")
                        }
                    } else {
                        debugLog("save token :: \(String(describing: pushToken))")
                        AppBox.shared.setPushToken(pushToken, pushYn: "")
                    }
                }
            }
        }
    }
    
    func appBoxPushSendToken(pushYn: String, completion: @escaping (Bool) -> Void) {
        if pushYn == "Y" {
            self.appBoxPushRequestPermissionForNotifications { result in
                if result {
                    Messaging.messaging().token { token, error in
                        debugLog("new Token :: \(String(describing: token))")
                        guard let pushToken = token else {
                            completion(false)
                            return
                        }
                        
                        if let oldToken = AppBox.shared.getPushToken() {
                            if oldToken != pushToken {
                                debugLog("not same save token :: \(String(describing: pushToken))")
                                AppBox.shared.setPushToken(pushToken, pushYn: pushYn) { success in
                                    completion(success)
                                }
                            } else {
                                completion(true)
                            }
                        } else {
                            debugLog("save token :: \(String(describing: pushToken))")
                            AppBox.shared.setPushToken(pushToken, pushYn: pushYn) { success in
                                completion(success)
                            }
                        }
                    }
                } else {
                    completion(false)
                }
            }
        } else {
            Messaging.messaging().token { token, error in
                guard let pushToken = token else {
                    completion(false)
                    return
                }
                
                if let oldToken = AppBox.shared.getPushToken() {
                    if oldToken != pushToken {
                        debugLog("not same save token :: \(String(describing: pushToken))")
                        AppBox.shared.setPushToken(pushToken, pushYn: pushYn) { success in
                            completion(success)
                        }
                    } else {
                        completion(true)
                    }
                } else {
                    debugLog("save token :: \(String(describing: pushToken))")
                    AppBox.shared.setPushToken(pushToken, pushYn: pushYn) { success in
                        completion(success)
                    }
                }
            }
        }
    }
}

extension AppBoxPushRepository: UNUserNotificationCenterDelegate {
    
    // 알림이 클릭이 되었을 때
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        debugLog("click :: \(response.notification.request.content.userInfo)")

        if let url = response.notification.request.content.userInfo["link"] as? String,
        let idx = response.notification.request.content.userInfo["idx"] as? String {
            AppBox.shared.pushMoveSetParam(url, idx)
            
            if UIApplication.shared.applicationState == .active || UIApplication.shared.applicationState == .inactive {
                AppBox.shared.pushMoveStart()
            }
        
        }
    }
    
    
    // foreground일 때, 알림이 발생
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .alert, .sound])
    }
}


extension AppBoxPushRepository: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        debugLog("token :: \(String(describing: fcmToken))")
    }
}
