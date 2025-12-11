//
//  FirebaseInitializationChecker.swift
//  AppBoxSnsLoginSDK
//
//  Created by mobilePartners on 1/24/25.
//

import Foundation
import FirebaseCore

/// Firebase 초기화 상태를 확인하는 유틸리티
///
/// 이 SDK는 AppBoxPushSDK의 Firebase 초기화 이후에만 사용 가능합니다.
/// Google 및 Apple 로그인을 사용하기 전에 반드시 Firebase가 초기화되어 있어야 합니다.
class FirebaseInitializationChecker {
    
    /// Firebase가 초기화되었는지 확인
    ///
    /// - Returns: Firebase가 초기화되어 있으면 true, 그렇지 않으면 false
    static func isFirebaseInitialized() -> Bool {
        return FirebaseApp.app() != nil
    }
    
    /// Firebase 초기화 상태를 확인하고, 초기화되지 않은 경우 에러를 반환
    ///
    /// - Throws: `AppBoxSnsLoginError.firebaseNotInitialized` - Firebase가 초기화되지 않은 경우
    static func checkFirebaseInitialization() throws {
        guard isFirebaseInitialized() else {
            debugLog("Firebase가 초기화되지 않았습니다. AppBoxPushSDK를 먼저 초기화해주세요.")
            throw AppBoxSnsLoginError.firebaseNotInitialized
        }
    }
}

