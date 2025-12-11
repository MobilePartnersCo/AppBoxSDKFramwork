//
//  AppBoxSnsLoginProtocol.swift
//  AppBoxSnsLoginSDK
//
//  Created by mobilePartners on 1/24/25.
//

import Foundation
import UIKit
import WebKit

/// AppBoxSnsLoginSDK에서 제공하는 SNS 로그인 프로토콜
///
/// 이 SDK는 AppBoxPushSDK의 Firebase 초기화 이후에만 정상 동작합니다.
/// Google 및 Apple 로그인을 사용하기 전에 반드시 Firebase가 초기화되어 있어야 합니다.
@objc public protocol AppBoxSnsLoginProtocol {
    
    // MARK: - Login Methods
    
    /// Google 로그인
    ///
    /// - Parameters:
    ///   - presentingViewController: 로그인 UI를 표시할 ViewController
    ///   - completion: 완료 콜백 (성공 여부, 결과 데이터, 에러)
    @objc(signInWithGoogle:completion:)
    func signInWithGoogle(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void)
    
    /// Apple 로그인
    ///
    /// - Parameters:
    ///   - presentingViewController: 로그인 UI를 표시할 ViewController
    ///   - completion: 완료 콜백 (성공 여부, 결과 데이터, 에러)
    @objc(signInWithApple:completion:)
    func signInWithApple(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void)
    
    /// Kakao 로그인
    ///
    /// - Parameters:
    ///   - presentingViewController: 로그인 UI를 표시할 ViewController
    ///   - completion: 완료 콜백 (성공 여부, 결과 데이터, 에러)
    @objc(signInWithKakao:completion:)
    func signInWithKakao(presentingViewController: UIViewController, completion: @escaping (Bool, [String: Any]?, Error?) -> Void)
    
    /// Naver 로그인
    ///
    /// - Parameters:
    ///   - webView: 웹뷰 (네이버 로그인에 필요)
    ///   - callId: 호출 ID (웹 브릿지용)
    ///   - completion: 완료 콜백 (성공 여부, 결과 데이터, 에러)
    @objc(signInWithNaver:callId:completion:)
    func signInWithNaver(webView: WKWebView, callId: String?, completion: @escaping (Bool, [String: Any]?, Error?) -> Void)
    
    // MARK: - Logout Methods
    
    /// Google 로그아웃
    ///
    /// - Parameter completion: 완료 콜백 (성공 여부, 에러)
    @objc(signOutWithGoogle:)
    func signOutWithGoogle(completion: @escaping (Bool, Error?) -> Void)
    
    /// Apple 로그아웃
    ///
    /// - Parameter completion: 완료 콜백 (성공 여부, 에러)
    @objc(signOutWithApple:)
    func signOutWithApple(completion: @escaping (Bool, Error?) -> Void)
    
    /// Kakao 로그아웃
    ///
    /// - Parameter completion: 완료 콜백 (성공 여부, 에러)
    @objc(signOutWithKakao:)
    func signOutWithKakao(completion: @escaping (Bool, Error?) -> Void)
    
    /// Naver 로그아웃
    ///
    /// - Parameter completion: 완료 콜백 (성공 여부, 에러)
    @objc(signOutWithNaver:)
    func signOutWithNaver(completion: @escaping (Bool, Error?) -> Void)
    
    // MARK: - URL Handling
    
    /// URL 핸들링
    ///
    /// 외부 앱에서 콜백으로 돌아올 때 URL을 처리합니다.
    ///
    /// - Parameter url: 처리할 URL
    /// - Returns: URL이 처리되었는지 여부 (true: 처리됨, false: 처리되지 않음)
    func handleURL(_ url: URL) -> Bool
    
    // MARK: - Initialization Methods
    
    /// Kakao 로그인 초기화
    ///
    /// AppDelegate의 `application(_:didFinishLaunchingWithOptions:)`에서 호출해야 합니다.
    ///
    /// - Parameter appKey: Kakao 앱 키
    @objc(initializeKakaoWithAppKey:)
    func initializeKakao(appKey: String)
    
    /// Naver 로그인 초기화
    ///
    /// AppDelegate의 `application(_:didFinishLaunchingWithOptions:)`에서 호출해야 합니다.
    ///
    /// - Parameters:
    ///   - appName: 앱 이름
    ///   - clientId: 네이버 클라이언트 ID
    ///   - clientSecret: 네이버 클라이언트 시크릿
    ///   - urlScheme: URL 스킴
    @objc(initializeNaverWithAppName:clientId:clientSecret:urlScheme:)
    func initializeNaver(appName: String, clientId: String, clientSecret: String, urlScheme: String)
}

