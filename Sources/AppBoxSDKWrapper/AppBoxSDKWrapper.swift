//
//  AppBoxSDKWrapper.swift
//  AppBoxSDK
//
//  이 파일은 AppBoxSDK 바이너리와 AppBoxNotificationSDK 간의 의존성을 연결하기 위한 래퍼입니다.
//  실제 구현은 AppBoxSDK.xcframework 바이너리에 포함되어 있습니다.
//

import Foundation
import AppBoxSDK
import AppBoxNotificationSDK

// 이 래퍼를 통해 사용자가 AppBoxSDK만 import하면
// AppBoxNotificationSDK도 자동으로 포함됩니다.
@available(iOS 13.0, *)
public final class AppBoxSDKBridge {
    private init() {}
}

