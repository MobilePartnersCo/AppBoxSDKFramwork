//
//  AppBoxSDK.swift
//  AppBoxSDKWrapper
//
//  이 파일은 SPM Wrapper 패턴을 위한 파일입니다.
//  AppBoxSDK (xcframework)를 re-export하고, 
//  모든 의존성을 전이시킵니다.
//

@_exported import AppBoxSDK

// Firebase
@_exported import FirebaseAuth
@_exported import FirebaseMessaging

// Google Sign-In
@_exported import GoogleSignIn

// Kakao SDK
@_exported import KakaoSDKUser
@_exported import KakaoSDKAuth

// Naver SDK
@_exported import NidThirdPartyLogin
