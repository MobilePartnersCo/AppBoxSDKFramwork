//
//  NaverLoginService.swift
//  AppBoxSnsLoginSDK
//
//  Created by mobilePartners on 1/24/25.
//

import Foundation
import UIKit
import WebKit
import NidThirdPartyLogin

/// Naver 로그인 서비스
class NaverLoginService {
    static let shared = NaverLoginService()
    
    private var currentCompletion: ((Bool, [String: Any]?, Error?) -> Void)?
    private weak var currentWebView: WKWebView?
    private var currentCallId: String?
    private static var isInitialized = false
    private static var naverConfig: (appName: String, clientId: String, clientSecret: String, urlScheme: String)?
    
    private init() {}
    
    /// 네이버 로그인 초기화
    ///
    /// - Parameters:
    ///   - appName: 앱 이름
    ///   - clientId: 네이버 클라이언트 ID
    ///   - clientSecret: 네이버 클라이언트 시크릿
    ///   - urlScheme: URL 스킴
    func initialize(appName: String, clientId: String, clientSecret: String, urlScheme: String) {
        guard !NaverLoginService.isInitialized else {
            debugLog("NaverLoginService: 이미 초기화됨")
            return
        }
        
        NaverLoginService.naverConfig = (appName: appName, clientId: clientId, clientSecret: clientSecret, urlScheme: urlScheme)
        NidOAuth.shared.initialize(
            appName: appName,
            clientId: clientId,
            clientSecret: clientSecret,
            urlScheme: urlScheme
        )
        NaverLoginService.isInitialized = true
        debugLog("NaverLoginService: 네이버 로그인 초기화 완료")
    }
    
    /// 네이버 로그인 초기화 (필요한 경우)
    private func initializeIfNeeded() {
        guard !NaverLoginService.isInitialized else {
            return
        }
        
        guard let config = NaverLoginService.naverConfig else {
            debugLog("NaverLoginService: 초기화 설정이 없음")
            return
        }
        
        NidOAuth.shared.initialize(
            appName: config.appName,
            clientId: config.clientId,
            clientSecret: config.clientSecret,
            urlScheme: config.urlScheme
        )
        NaverLoginService.isInitialized = true
        debugLog("NaverLoginService: 네이버 로그인 초기화 완료")
    }
    
    /// Naver 로그인 실행
    ///
    /// - Parameters:
    ///   - webView: 웹뷰 (네이버 로그인에 필요)
    ///   - callId: 호출 ID (웹 브릿지용)
    ///   - completion: 완료 콜백 (성공 여부, 결과 데이터, 에러)
    func signIn(webView: WKWebView, callId: String?, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        self.currentWebView = webView
        self.currentCallId = callId
        self.currentCompletion = completion
        
        // 초기화 확인
        guard NaverLoginService.isInitialized || NaverLoginService.naverConfig != nil else {
            debugLog("signInWithNaver 실패: NaverLoginService가 초기화되지 않음")
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "NaverLoginService가 초기화되지 않았습니다. AppDelegate에서 initializeNaver(appName:clientId:clientSecret:urlScheme:)를 호출해주세요."])
            completion(false, nil, error)
            return
        }
        
        initializeIfNeeded()
        
        // 네이버 로그인 요청
        NidOAuth.shared.requestLogin { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let loginResult):
                debugLog("네이버 로그인 성공: accessToken 존재=\(loginResult.accessToken != nil)")
                
                // accessToken, refreshToken 저장
                let accessToken = loginResult.accessToken.tokenString
                let refreshToken = loginResult.refreshToken.tokenString
                self.getUserProfile(accessToken: accessToken, refreshToken: refreshToken)
                
            case .failure(let error):
                debugLog("네이버 로그인 실패: \(error.localizedDescription)")
                self.currentCompletion?(false, nil, error)
                self.reset()
            }
        }
    }
    
    private func getUserProfile(accessToken: String, refreshToken: String) {
        NidOAuth.shared.getUserProfile(accessToken: accessToken) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let profile):
                debugLog("네이버 사용자 정보 조회 성공")
                
                // 결과 데이터 구성
                var resultData: [String: Any] = [
                    "accessToken": accessToken,
                    "refreshToken": refreshToken
                ]
                
                // 사용자 정보 추가
                if let id = profile["id"] {
                    resultData["uid"] = id
                }
                if let email = profile["email"] {
                    resultData["email"] = email
                }
                if let name = profile["name"] {
                    resultData["displayName"] = name
                }
                if let profileImage = profile["profile_image"] {
                    resultData["photoURL"] = profileImage
                }
                
                self.currentCompletion?(true, resultData, nil)
                
            case .failure(let error):
                debugLog("네이버 사용자 정보 조회 실패: \(error.localizedDescription)")
                // 토큰은 있지만 사용자 정보를 가져오지 못한 경우, 토큰만 반환
                let resultData: [String: Any] = [
                    "accessToken": accessToken,
                    "refreshToken": refreshToken
                ]
                self.currentCompletion?(true, resultData, nil)
            }
            
            self.reset()
        }
    }
    
    /// Naver 로그아웃
    ///
    /// - Parameter completion: 완료 콜백 (성공 여부, 에러)
    func signOut(completion: @escaping (Bool, Error?) -> Void) {
        // 초기화 확인
        guard NaverLoginService.isInitialized || NaverLoginService.naverConfig != nil else {
            debugLog("signOutWithNaver: NaverLoginService가 초기화되지 않음, 스킵")
            completion(false, nil)
            return
        }
        
        initializeIfNeeded()
        
        // accessToken 또는 refreshToken이 있으면 로그인된 상태
        let hasSession = NidOAuth.shared.accessToken != nil || NidOAuth.shared.refreshToken != nil
        
        if hasSession {
            debugLog("네이버 로그인 상태 확인, 로그아웃 실행")
            
            // disconnect를 통해 서버에 토큰 삭제 요청
            NidOAuth.shared.disconnect { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // logout() 호출
                        NidOAuth.shared.logout()
                        debugLog("NidOAuth disconnect 성공")
                        completion(true, nil)
                    case .failure(let error):
                        debugLog("NidOAuth disconnect 실패: \(error.localizedDescription)")
                        completion(false, error)
                    }
                }
            }
        } else {
            debugLog("네이버 로그인 상태 아님, 스킵")
            DispatchQueue.main.async {
                completion(false, nil) // 세션이 없었음
            }
        }
    }
    
    /// Naver 로그인 URL 처리
    ///
    /// - Parameter url: 처리할 URL
    /// - Returns: URL이 처리되었는지 여부
    func handleURL(_ url: URL) -> Bool {
        return NidOAuth.shared.handleURL(url)
    }
    
    private func reset() {
        currentCompletion = nil
        currentWebView = nil
        currentCallId = nil
    }
}

