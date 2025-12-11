//
//  AppleLoginService.swift
//  AppBoxSnsLoginSDK
//
//  Created by mobilePartners on 1/24/25.
//

import UIKit
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth

/// Apple 로그인 서비스
@available(iOS 13.0, *)
class AppleLoginService: NSObject {
    
    // Apple Sign-In을 위한 프로퍼티
    private var currentNonce: String?
    private var appleSignInCompletion: ((Bool, [String: Any]?, Error?) -> Void)?
    
    /// Apple 로그인 실행
    ///
    /// - Parameters:
    ///   - presentingViewController: 로그인 UI를 표시할 ViewController
    ///   - completion: 완료 콜백 (성공 여부, 결과 데이터, 에러)
    func signIn(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        debugLog("signInWithApple 시작")
        
        // Firebase 초기화 검증 (재시도 로직 제거)
        do {
            try FirebaseInitializationChecker.checkFirebaseInitialization()
        } catch {
            debugLog("signInWithApple 실패: Firebase 초기화되지 않음")
            completion(false, nil, error)
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
    }
    
    /// Apple 로그아웃
    ///
    /// - Parameter completion: 완료 콜백 (성공 여부, 에러)
    func signOut(completion: @escaping (Bool, Error?) -> Void) {
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
    
    // MARK: - Helper Methods
    
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
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate (iOS 13+)
@available(iOS 13.0, *)
extension AppleLoginService: ASAuthorizationControllerDelegate {
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
extension AppleLoginService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first!
    }
}

