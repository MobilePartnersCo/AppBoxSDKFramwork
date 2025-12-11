//
//  GoogleLoginService.swift
//  AppBoxSnsLoginSDK
//
//  Created by mobilePartners on 1/24/25.
//

import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

/// Google 로그인 서비스
class GoogleLoginService {
    
    /// Google 로그인 실행
    ///
    /// - Parameters:
    ///   - presentingViewController: 로그인 UI를 표시할 ViewController
    ///   - completion: 완료 콜백 (성공 여부, 결과 데이터, 에러)
    static func signIn(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        debugLog("signInWithGoogle 시작")
        
        // Firebase 초기화 검증 (재시도 로직 제거)
        do {
            try FirebaseInitializationChecker.checkFirebaseInitialization()
        } catch {
            debugLog("signInWithGoogle 실패: Firebase 초기화되지 않음")
            completion(false, nil, error)
            return
        }
        
        debugLog("signInWithGoogle: Firebase 초기화 확인 완료")
        
        // Google Sign-In 설정
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            debugLog("signInWithGoogle 실패: Firebase Client ID를 찾을 수 없음")
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase Client ID를 찾을 수 없습니다."])
            completion(false, nil, error)
            return
        }
        debugLog("signInWithGoogle: Client ID 확인 완료 - \(clientID.prefix(20))...")
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        debugLog("signInWithGoogle: GIDConfiguration 설정 완료")
        
        // Google 로그인 실행
        debugLog("signInWithGoogle: GIDSignIn.sharedInstance.signIn 호출 시작")
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let error = error {
                debugLog("signInWithGoogle: GIDSignIn 실패 - domain=\((error as NSError).domain), code=\((error as NSError).code), description=\(error.localizedDescription)")
                completion(false, nil, error)
                return
            }
            
            debugLog("signInWithGoogle: GIDSignIn 성공")
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                debugLog("signInWithGoogle 실패: Google 토큰을 가져올 수 없음 - user=\(result?.user != nil ? "존재" : "nil"), idToken=\(result?.user.idToken?.tokenString != nil ? "존재" : "nil")")
                let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google 토큰을 가져올 수 없습니다."])
                completion(false, nil, error)
                return
            }
            
            debugLog("signInWithGoogle: Google ID Token 획득 완료")
            
            // Firebase Auth에 Google 인증 정보 전달
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            debugLog("signInWithGoogle: GoogleAuthProvider credential 생성 완료")
            
            debugLog("signInWithGoogle: Auth.auth().signIn 호출 시작")
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    debugLog("signInWithGoogle: Firebase Auth 실패 - domain=\((error as NSError).domain), code=\((error as NSError).code), description=\(error.localizedDescription)")
                    completion(false, nil, error)
                } else if let authResult = authResult {
                    debugLog("signInWithGoogle: Firebase Auth 성공 - uid=\(authResult.user.uid)")
                    // ID Token 획득 및 결과 반환
                    authResult.user.getIDToken { token, error in
                        if let error = error {
                            debugLog("signInWithGoogle: getIDToken 실패 - \(error.localizedDescription)")
                            completion(false, nil, error)
                            return
                        }
                        
                        guard let token = token else {
                            debugLog("signInWithGoogle 실패: Firebase ID Token이 nil")
                            completion(false, nil, error)
                            return
                        }
                        
                        debugLog("signInWithGoogle: Firebase ID Token 획득 완료")
                        
                        var result: [String: Any] = [
                            "token": token,
                            "provider": "google.com",
                            "uid": authResult.user.uid,
                            "email": authResult.user.email ?? "",
                            "displayName": authResult.user.displayName ?? "",
                            "photoURL": authResult.user.photoURL?.absoluteString ?? ""
                        ]
                        
                        // 추가 사용자 정보
                        if let profile = authResult.additionalUserInfo?.profile {
                            result.merge(profile) { (_, new) in new }
                            debugLog("signInWithGoogle: 추가 사용자 정보 병합 완료")
                        }
                        
                        debugLog("signInWithGoogle: 최종 성공 - uid=\(authResult.user.uid), email=\(authResult.user.email ?? "nil")")
                        completion(true, result, nil)
                    }
                } else {
                    debugLog("signInWithGoogle 실패: 알 수 없는 오류 (authResult와 error 모두 nil)")
                    let error = NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "알 수 없는 오류"])
                    completion(false, nil, error)
                }
            }
        }
    }
    
    /// Google 로그아웃
    ///
    /// - Parameter completion: 완료 콜백 (성공 여부, 에러)
    static func signOut(completion: @escaping (Bool, Error?) -> Void) {
        debugLog("signOutWithGoogle 시작")
        
        // Firebase 초기화 확인
        guard FirebaseApp.app() != nil else {
            debugLog("signOutWithGoogle 실패: Firebase가 초기화되지 않음")
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase가 초기화되지 않았습니다."])
            completion(false, error)
            return
        }
        
        // 실제 세션 확인: currentUser가 있고 providerData에 google.com이 있는지 확인
        guard let currentUser = Auth.auth().currentUser else {
            debugLog("signOutWithGoogle: 현재 로그인된 사용자 없음, 스킵")
            completion(false, nil) // 세션이 없었음
            return
        }
        
        // providerData에서 google.com 확인
        let hasGoogleProvider = currentUser.providerData.contains { provider in
            provider.providerID == "google.com"
        }
        
        guard hasGoogleProvider else {
            debugLog("signOutWithGoogle: Google 세션 없음, 스킵")
            completion(false, nil) // Google 세션이 없었음
            return
        }
        
        debugLog("signOutWithGoogle: Google 세션 확인됨, 로그아웃 실행")
        
        do {
            // Google Sign-In 로그아웃
            GIDSignIn.sharedInstance.signOut()
            debugLog("signOutWithGoogle: GIDSignIn 로그아웃 완료")
            
            // Firebase Auth 로그아웃
            try Auth.auth().signOut()
            debugLog("signOutWithGoogle: Firebase Auth 로그아웃 완료")
            
            completion(true, nil)
        } catch {
            debugLog("signOutWithGoogle 실패: \(error.localizedDescription)")
            completion(false, error)
        }
    }
    
    /// Google 로그인 URL 처리
    ///
    /// - Parameter url: 처리할 URL
    /// - Returns: URL이 처리되었는지 여부
    static func handleURL(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

