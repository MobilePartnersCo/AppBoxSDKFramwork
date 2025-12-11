//
//  AppBoxSnsLoginRepository.swift
//  AppBoxSnsLoginSDK
//
//  Created by mobilePartners on 1/24/25.
//

import UIKit
import WebKit

/// AppBoxSnsLoginSDK의 구현체
///
/// 이 SDK는 AppBoxPushSDK의 Firebase 초기화 이후에만 정상 동작합니다.
/// Google 및 Apple 로그인을 사용하기 전에 반드시 Firebase가 초기화되어 있어야 합니다.
class AppBoxSnsLoginRepository: NSObject, AppBoxSnsLoginProtocol {
    
    static let shared = AppBoxSnsLoginRepository()
    
    // Apple 로그인 서비스 인스턴스 (iOS 13+)
    @available(iOS 13.0, *)
    private lazy var appleLoginService: AppleLoginService = {
        return AppleLoginService()
    }()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Login Methods
    
    @objc(signInWithGoogle:completion:)
    func signInWithGoogle(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        GoogleLoginService.signIn(presentingViewController: presentingViewController, completion: completion)
    }
    
    @objc(signInWithApple:completion:)
    func signInWithApple(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        if #available(iOS 13.0, *) {
            appleLoginService.signIn(presentingViewController: presentingViewController, completion: completion)
        } else {
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign-In은 iOS 13 이상에서만 지원됩니다."])
            completion(false, nil, error)
        }
    }
    
    @objc(signInWithKakao:completion:)
    func signInWithKakao(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        KakaoLoginService.signIn(presentingViewController: presentingViewController, completion: completion)
    }
    
    @objc(signInWithNaver:callId:completion:)
    func signInWithNaver(webView: WKWebView, callId: String?, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        NaverLoginService.shared.signIn(webView: webView, callId: callId, completion: completion)
    }
    
    // MARK: - Logout Methods
    
    @objc(signOutWithGoogle:)
    func signOutWithGoogle(completion: @escaping (Bool, Error?) -> Void) {
        GoogleLoginService.signOut(completion: completion)
    }
    
    @objc(signOutWithApple:)
    func signOutWithApple(completion: @escaping (Bool, Error?) -> Void) {
        if #available(iOS 13.0, *) {
            appleLoginService.signOut(completion: completion)
        } else {
            completion(false, nil)
        }
    }
    
    @objc(signOutWithKakao:)
    func signOutWithKakao(completion: @escaping (Bool, Error?) -> Void) {
        KakaoLoginService.signOut(completion: completion)
    }
    
    @objc(signOutWithNaver:)
    func signOutWithNaver(completion: @escaping (Bool, Error?) -> Void) {
        NaverLoginService.shared.signOut(completion: completion)
    }
    
    // MARK: - URL Handling
    
    @MainActor func handleURL(_ url: URL) -> Bool {
        debugLog("handleURL 시작: \(url.absoluteString)")
        
        // Google 로그인 URL 처리
        if GoogleLoginService.handleURL(url) {
            debugLog("구글 로그인 URL 처리 완료")
            return true
        }
        
        // Kakao 로그인 URL 처리
        if KakaoLoginService.handleURL(url) {
            debugLog("카카오 로그인 URL 처리 완료")
            return true
        }
        
        // Naver 로그인 URL 처리
        if NaverLoginService.shared.handleURL(url) {
            debugLog("네이버 로그인 URL 처리 완료")
            return true
        }
        
        debugLog("AppBoxSnsLoginSDK에서 처리할 수 없는 URL")
        return false
    }
    
    // MARK: - Initialization Methods
    
    @objc(initializeKakaoWithAppKey:)
    func initializeKakao(appKey: String) {
        KakaoLoginService.initialize(appKey: appKey)
    }
    
    @objc(initializeNaverWithAppName:clientId:clientSecret:urlScheme:)
    func initializeNaver(appName: String, clientId: String, clientSecret: String, urlScheme: String) {
        NaverLoginService.shared.initialize(appName: appName, clientId: clientId, clientSecret: clientSecret, urlScheme: urlScheme)
    }
}

