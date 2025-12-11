//
//  AppBoxSnsLoginError.swift
//  AppBoxSnsLoginSDK
//
//  Created by mobilePartners on 1/24/25.
//

import Foundation

/// AppBoxSnsLoginSDK에서 발생하는 에러 타입
public enum AppBoxSnsLoginError: Error, LocalizedError {
    /// Firebase가 초기화되지 않음
    /// 이 SDK는 AppBoxPushSDK의 Firebase 초기화 이후에만 사용 가능합니다.
    case firebaseNotInitialized
    
    /// AppBoxSnsLoginSDK를 찾을 수 없음
    case sdkNotAvailable
    
    /// 알 수 없는 에러
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .firebaseNotInitialized:
            return "Firebase가 초기화되지 않았습니다. AppBoxPushSDK를 먼저 초기화해주세요."
        case .sdkNotAvailable:
            return "AppBoxSnsLoginSDK를 찾을 수 없습니다."
        case .unknown(let message):
            return "알 수 없는 오류: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .firebaseNotInitialized:
            return "AppBoxPushSDK의 appBoxPushInitWithLauchOptions()를 먼저 호출한 후 SNS 로그인을 시도해주세요."
        case .sdkNotAvailable:
            return "AppBoxSnsLoginSDK가 프로젝트에 포함되어 있는지 확인해주세요."
        case .unknown:
            return "잠시 후 다시 시도해주세요."
        }
    }
}

