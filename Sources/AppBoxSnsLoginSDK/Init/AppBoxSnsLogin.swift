//
//  AppBoxSnsLogin.swift
//  AppBoxSnsLoginSDK
//
//  Created by mobilePartners on 1/24/25.
//

import Foundation

/// AppBoxSnsLoginSDK의 진입점
@objc(AppBoxSnsLogin)
public class AppBoxSnsLogin: NSObject {
    /// 공유 인스턴스
    @objc public static let shared: AppBoxSnsLoginProtocol = AppBoxSnsLoginRepository.shared
}

