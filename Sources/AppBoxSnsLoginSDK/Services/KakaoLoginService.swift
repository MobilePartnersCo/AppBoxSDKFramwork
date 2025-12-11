//
//  KakaoLoginService.swift
//  AppBoxSnsLoginSDK
//
//  Created by mobilePartners on 1/24/25.
//

import UIKit
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

/// Kakao 로그인 서비스
class KakaoLoginService {
    
    // Kakao SDK 초기화 플래그
    private static var isKakaoInitialized = false
    private static var kakaoAppKey: String?
    
    /// Kakao SDK 초기화
    ///
    /// - Parameter appKey: Kakao 앱 키
    static func initialize(appKey: String) {
        guard !isKakaoInitialized else {
            debugLog("KakaoLoginService: 이미 초기화됨")
            return
        }
        
        kakaoAppKey = appKey
        KakaoSDK.initSDK(appKey: appKey)
        isKakaoInitialized = true
        debugLog("KakaoLoginService: KakaoSDK 초기화 완료")
    }
    
    /// Kakao 로그인 실행
    ///
    /// - Parameters:
    ///   - presentingViewController: 로그인 UI를 표시할 ViewController
    ///   - completion: 완료 콜백 (성공 여부, 결과 데이터, 에러)
    static func signIn(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        debugLog("signInWithKakao 시작")
        
        // Kakao SDK 초기화 확인
        guard isKakaoInitialized, let appKey = kakaoAppKey else {
            debugLog("signInWithKakao 실패: KakaoSDK가 초기화되지 않음")
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "KakaoSDK가 초기화되지 않았습니다. AppDelegate에서 initializeKakao(appKey:)를 호출해주세요."])
            completion(false, nil, error)
            return
        }
        
        // 카카오톡 설치 여부에 따라 로그인 방식 분기
        if UserApi.isKakaoTalkLoginAvailable() {
            debugLog("signInWithKakao: 카카오톡으로 로그인 시도")
            UserApi.shared.loginWithKakaoTalk { oauthToken, error in
                handleKakaoLoginResult(oauthToken: oauthToken, error: error, completion: completion)
            }
        } else {
            debugLog("signInWithKakao: 카카오 계정으로 로그인 시도")
            UserApi.shared.loginWithKakaoAccount { oauthToken, error in
                handleKakaoLoginResult(oauthToken: oauthToken, error: error, completion: completion)
            }
        }
    }
    
    private static func handleKakaoLoginResult(oauthToken: OAuthToken?, error: Error?, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        if let error = error {
            debugLog("signInWithKakao 실패: \(error.localizedDescription)")
            completion(false, nil, error)
            return
        }
        
        guard let token = oauthToken else {
            debugLog("signInWithKakao 실패: 토큰이 nil")
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "카카오 토큰을 가져올 수 없습니다."])
            completion(false, nil, error)
            return
        }
        
        debugLog("signInWithKakao: 토큰 획득 성공, 사용자 정보 조회 시작")
        
        // 사용자 정보 조회
        UserApi.shared.me { user, error in
            if let error = error {
                debugLog("signInWithKakao: 사용자 정보 조회 실패 - \(error.localizedDescription)")
                // 토큰은 있지만 사용자 정보 조회 실패 시에도 토큰 정보만 반환
                let result: [String: Any] = [
                    "accessToken": token.accessToken,
                    "refreshToken": token.refreshToken ?? "",
                    "provider": "kakao.com"
                ]
                completion(true, result, nil)
                return
            }
            
            guard let user = user else {
                debugLog("signInWithKakao: 사용자 정보가 nil")
                let result: [String: Any] = [
                    "accessToken": token.accessToken,
                    "refreshToken": token.refreshToken ?? "",
                    "provider": "kakao.com"
                ]
                completion(true, result, nil)
                return
            }
            
            debugLog("signInWithKakao: 사용자 정보 조회 성공 - id=\(user.id ?? 0)")
            
            let result: [String: Any] = [
                "uid": String(user.id ?? 0),
                "email": user.kakaoAccount?.email ?? "",
                "displayName": user.kakaoAccount?.profile?.nickname ?? "",
                "photoURL": user.kakaoAccount?.profile?.profileImageUrl?.absoluteString ?? "",
                "accessToken": token.accessToken,
                "refreshToken": token.refreshToken ?? "",
                "provider": "kakao.com"
            ]
            
            debugLog("signInWithKakao: 최종 성공 - uid=\(user.id ?? 0), email=\(user.kakaoAccount?.email ?? "nil")")
            completion(true, result, nil)
        }
    }
    
    /// Kakao 로그아웃
    ///
    /// - Parameter completion: 완료 콜백 (성공 여부, 에러)
    static func signOut(completion: @escaping (Bool, Error?) -> Void) {
        debugLog("signOutWithKakao 시작")
        
        // Kakao SDK 초기화 확인
        guard isKakaoInitialized else {
            debugLog("signOutWithKakao: KakaoSDK가 초기화되지 않음, 스킵")
            completion(false, nil)
            return
        }
        
        // 토큰 존재 여부 확인
        if AuthApi.hasToken() {
            debugLog("signOutWithKakao: 카카오 세션 확인됨, 로그아웃 실행")
            
            UserApi.shared.unlink { error in
                if let error = error {
                    debugLog("signOutWithKakao 실패: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    debugLog("signOutWithKakao: 로그아웃 완료")
                    completion(true, nil)
                }
            }
        } else {
            debugLog("signOutWithKakao: 카카오 세션 없음, 스킵")
            completion(false, nil)
        }
    }
    
    /// Kakao 로그인 URL 처리
    ///
    /// - Parameter url: 처리할 URL
    /// - Returns: URL이 처리되었는지 여부
    @MainActor static func handleURL(_ url: URL) -> Bool {
        if AuthApi.isKakaoTalkLoginUrl(url) {
            _ = AuthController.handleOpenUrl(url: url)
            return true
        }
        return false
    }
}

