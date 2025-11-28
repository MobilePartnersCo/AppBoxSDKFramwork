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
    
    /**
     # URL 핸들링
     
     외부 앱에서 콜백으로 돌아올 때 URL을 처리합니다.
     
     ## Parameters
     - `url`: 처리할 URL
     
     ## Returns
     - `Bool`: URL이 처리되었는지 여부 (true: 처리됨, false: 처리되지 않음)
     
     ## Author
     - jw.jeong
     
     ## Example
     ```swift
     func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
         // 로그인 등 URL 처리
         if AppBoxPush.shared.handleURL(url) {
             return true
         }
         
         // 기타 URL 처리...
         return false
     }
     ```
     
      ## Note
     - 이 메서드는 `AppDelegate.swift`의 `application(_:open:options:)`에서 호출해야 합니다
     */
    func handleURL(_ url: URL) -> Bool

    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxPushInitWithLauchOptions()
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxPushSendToken(pushYn: String, completion: @escaping (Bool, Bool) -> Void)
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc dynamic func appBoxSetSegment(segment:[String: String], completion: @escaping (Bool) -> Void)
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc(signInWithGoogle:completion:)
    dynamic func signInWithGoogle(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void)
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc(signInWithApple:completion:)
    dynamic func signInWithApple(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void)
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc(signOutWithGoogle:)
    dynamic func signOutWithGoogle(completion: @escaping (Bool, Error?) -> Void)
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc(signOutWithApple:)
    dynamic func signOutWithApple(completion: @escaping (Bool, Error?) -> Void)
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc(signInWithKakao:completion:)
    dynamic func signInWithKakao(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void)
    
    @available(*, deprecated, message: "Internal use only. Do not use.")
    @objc(signOutWithKakao:)
    dynamic func signOutWithKakao(completion: @escaping (Bool, Error?) -> Void)
}
