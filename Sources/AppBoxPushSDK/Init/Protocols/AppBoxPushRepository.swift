//
//  AppBoxPushRepository.swift
//  appboxpush
//
//  Created by mobilePartners on 1/24/25.
//


import UIKit
@_spi(AppBoxPushSDK) import AppBoxSDK
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser


class AppBoxPushRepository: NSObject, AppBoxPushProtocol {

    static let shared = AppBoxPushRepository()
    let center = UNUserNotificationCenter.current()
    
    // 초기화 중복 호출 방지 플래그
    private var isInitializing = false
    
    // Kakao SDK 초기화 플래그
    private var isKakaoInitialized = false
    
    // Apple Sign-In을 위한 프로퍼티 (iOS 13+)
    @available(iOS 13.0, *)
    private var currentNonce: String?
    @available(iOS 13.0, *)
    private var appleSignInCompletion: ((Bool, [String: Any]?, Error?) -> Void)?
    
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
        
        AppBox.shared.getPushInfo(projectId) { [weak self] isSuccess, model in
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
                    options.clientID =
                    "600053873847-aq3f2j3598dcqup1ufp2sqqv4bo3ftq6.apps.googleusercontent.com"
//                    if let clientID = info.client_id {
//                        options.clientID = clientID
//                    }
                    
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
    
    // MARK: - SNS Login
    
    @objc(signInWithGoogle:completion:)
    func signInWithGoogle(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        debugLog("signInWithGoogle 시작")
        
        // 방법 2: Firebase 초기화 확인 및 재시도
        guard FirebaseApp.app() != nil else {
            debugLog("signInWithGoogle: Firebase가 초기화되지 않음, 초기화 시도 후 재시도")
            
            // 초기화 시도
            appBoxPushInitWithLauchOptions()
            
            // 짧은 딜레이 후 재시도 (최대 1회)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if FirebaseApp.app() != nil {
                    // 재귀적으로 다시 호출
                    debugLog("signInWithGoogle: Firebase 초기화 완료, 재시도")
                    self.signInWithGoogle(presentingViewController: presentingViewController, completion: completion)
                } else {
                    debugLog("signInWithGoogle 실패: Firebase 초기화 타임아웃")
                    let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase가 초기화되지 않았습니다. 잠시 후 다시 시도해주세요."])
                    completion(false, nil, error)
                }
            }
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
    
    @objc(signInWithApple:completion:)
    func signInWithApple(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        // iOS 13 이상 체크
        if #available(iOS 13.0, *) {
            debugLog("signInWithApple 시작")
            
            // 방법 2: Firebase 초기화 확인 및 재시도
            guard FirebaseApp.app() != nil else {
                debugLog("signInWithApple: Firebase가 초기화되지 않음, 초기화 시도 후 재시도")
                
                // 초기화 시도
                appBoxPushInitWithLauchOptions()
                
                // 짧은 딜레이 후 재시도 (최대 1회)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    if FirebaseApp.app() != nil {
                        // 재귀적으로 다시 호출
                        debugLog("signInWithApple: Firebase 초기화 완료, 재시도")
                        self.signInWithApple(presentingViewController: presentingViewController, completion: completion)
                    } else {
                        debugLog("signInWithApple 실패: Firebase 초기화 타임아웃")
                        let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase가 초기화되지 않았습니다. 잠시 후 다시 시도해주세요."])
                        completion(false, nil, error)
                    }
                }
                return
            }
            
            debugLog("signInWithApple: Firebase 초기화 확인 완료")
            
            self.appleSignInCompletion = completion
            
            // Nonce 생성 (보안)
            let nonce = randomNonceString()
            currentNonce = nonce
            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        } else {
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign-In은 iOS 13 이상에서만 지원됩니다."])
            completion(false, nil, error)
        }
    }
    
    // MARK: - Kakao Login
    
    @objc(signInWithKakao:completion:)
    func signInWithKakao(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        debugLog("signInWithKakao 시작")
        
        // Kakao SDK 초기화 (최초 1회)
        if !isKakaoInitialized {
            KakaoSDK.initSDK(appKey: "403867c55d0a9a3e9f73ff8c128656e9")
            isKakaoInitialized = true
            debugLog("signInWithKakao: KakaoSDK 초기화 완료")
        }
        
        // 카카오톡 설치 여부에 따라 로그인 방식 분기
        if UserApi.isKakaoTalkLoginAvailable() {
            debugLog("signInWithKakao: 카카오톡으로 로그인 시도")
            UserApi.shared.loginWithKakaoTalk { [weak self] oauthToken, error in
                self?.handleKakaoLoginResult(oauthToken: oauthToken, error: error, completion: completion)
            }
        } else {
            debugLog("signInWithKakao: 카카오 계정으로 로그인 시도")
            UserApi.shared.loginWithKakaoAccount { [weak self] oauthToken, error in
                self?.handleKakaoLoginResult(oauthToken: oauthToken, error: error, completion: completion)
            }
        }
    }
    
    private func handleKakaoLoginResult(oauthToken: OAuthToken?, error: Error?, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
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
    
    // MARK: - SNS Logout
    
    @objc(signOutWithGoogle:)
    func signOutWithGoogle(completion: @escaping (Bool, Error?) -> Void) {
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
    
    @objc(signOutWithApple:)
    func signOutWithApple(completion: @escaping (Bool, Error?) -> Void) {
        debugLog("signOutWithApple 시작")
        
        // Firebase 초기화 확인
        guard FirebaseApp.app() != nil else {
            debugLog("signOutWithApple 실패: Firebase가 초기화되지 않음")
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase가 초기화되지 않았습니다."])
            completion(false, error)
            return
        }
        
        // 실제 세션 확인: currentUser가 있고 providerData에 apple.com이 있는지 확인
        guard let currentUser = Auth.auth().currentUser else {
            debugLog("signOutWithApple: 현재 로그인된 사용자 없음, 스킵")
            completion(false, nil) // 세션이 없었음
            return
        }
        
        // providerData에서 apple.com 확인
        let hasAppleProvider = currentUser.providerData.contains { provider in
            provider.providerID == "apple.com"
        }
        
        guard hasAppleProvider else {
            debugLog("signOutWithApple: Apple 세션 없음, 스킵")
            completion(false, nil) // Apple 세션이 없었음
            return
        }
        
        debugLog("signOutWithApple: Apple 세션 확인됨, 로그아웃 실행")
        
        do {
            // Firebase Auth 로그아웃
            try Auth.auth().signOut()
            debugLog("signOutWithApple: Firebase Auth 로그아웃 완료")
            
            completion(true, nil)
        } catch {
            debugLog("signOutWithApple 실패: \(error.localizedDescription)")
            completion(false, error)
        }
    }
    
    @objc(signOutWithKakao:)
    func signOutWithKakao(completion: @escaping (Bool, Error?) -> Void) {
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
            
//            UserApi.shared.logout { error in
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
    
    // MARK: - Kakao URL Handling
    
    @MainActor func handleURL(_ url: URL) -> Bool {
        debugLog("handleURL 시작: \(url.absoluteString)")
        
        if GIDSignIn.sharedInstance.handle(url) {
            debugLog("구글 or 애플 로그인 URL 처리 완료")
            return true
        }
        
        if (AuthApi.isKakaoTalkLoginUrl(url)) {
            _ = AuthController.handleOpenUrl(url: url)
            debugLog("카카오 로그인 URL 처리 완료")
            return true
        }
        
        debugLog("AppBoxPushSDK에서 처리할 수 없는 URL")
        return false
    }
}

// MARK: - ASAuthorizationControllerDelegate (iOS 13+)
@available(iOS 13.0, *)
extension AppBoxPushRepository: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple 인증 정보를 가져올 수 없습니다."])
            appleSignInCompletion?(false, nil, error)
            return
        }
        
        guard let nonce = currentNonce else {
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid state: A login callback was received, but no login request was sent."])
            appleSignInCompletion?(false, nil, error)
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            let error = NSError(domain: "AppBoxAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])
            appleSignInCompletion?(false, nil, error)
            return
        }
        
        // Firebase Auth에 Apple 인증 정보 전달
        let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                self.appleSignInCompletion?(false, nil, error)
            } else if let authResult = authResult {
                // ID Token 획득 및 결과 반환
                authResult.user.getIDToken { token, error in
                    guard let token = token else {
                        self.appleSignInCompletion?(false, nil, error)
                        return
                    }
                    
                    var result: [String: Any] = [
                        "token": token,
                        "provider": "apple.com",
                        "uid": authResult.user.uid,
                        "email": authResult.user.email ?? "",
                        "displayName": authResult.user.displayName ?? ""
                    ]
                    
                    // Apple은 photoURL이 없을 수 있음
                    if let photoURL = authResult.user.photoURL {
                        result["photoURL"] = photoURL.absoluteString
                    }
                    
                    self.appleSignInCompletion?(true, result, nil)
                }
            } else {
                let error = NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "알 수 없는 오류"])
                self.appleSignInCompletion?(false, nil, error)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        appleSignInCompletion?(false, nil, error)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding (iOS 13+)
@available(iOS 13.0, *)
extension AppBoxPushRepository: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first!
    }
    
    // MARK: - Helper Methods
    
    @available(iOS 13.0, *)
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    @available(iOS 13.0, *)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}
