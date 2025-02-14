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
                
                FirebaseApp.configure(options: options)
                
                Messaging.messaging().delegate = self
                self?.center.delegate = self
                
                UIApplication.shared.registerForRemoteNotifications()
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
        self.appBoxPushRequestPermissionForNotifications { result in
            if result {
                AppBox.shared.setPushToken(fcmToken)
            }
        }
    }
}
