![AppBox SDK](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSDKFramwork/main/resource/image/AppboxVisual.jpg)

# AppBox SDK for iOS

[![Swift Package Manager](https://img.shields.io/badge/SPM-Compatible-green.svg)](https://swift.org/package-manager/)
[![Version](https://img.shields.io/github/v/tag/MobilePartnersCo/AppBoxSDKFramwork?label=version)](https://github.com/MobilePartnersCo/AppBoxSDKFramwork/releases)

AppBox SDK는 모바일 웹 서비스를 iOS 앱으로 제공하고, WebView·Push·Native In-App·SNS
로그인·HealthKit·AppsFlyer 기능을 네이티브 앱에 연결하는 SDK입니다.

일반 서비스 앱은 `AppBox.initialize(...)`로 초기화하고 `AppBox.*` 정적 공개 함수를
사용합니다. 기본 통합에는 `AppBoxSDK`와 `AppBoxPushSDK`가 모두 필요합니다. 이 문서의
주요 예제는 Swift와 Objective-C를 함께 제공합니다.

## 목차

- [공식 링크](#공식-링크)
- [지원 환경](#지원-환경)
- [Swift Package Manager로 설치](#swift-package-manager로-설치)
- [Product 선택](#product-선택)
- [설정값 준비표](#설정값-준비표)
- [기능별 앱 설정](#기능별-앱-설정)
- [SDK 초기화](#sdk-초기화)
- [AppBox 관리 화면](#appbox-관리-화면)
- [고객사 WKWebView 연결](#고객사-wkwebview-연결)
- [Push lifecycle](#push-lifecycle)
- [Notification Service Extension](#notification-service-extension)
- [Native In-App](#native-in-app)
- [SNS 로그인](#sns-로그인)
- [HealthKit](#healthkit)
- [사용자 여정과 전환](#사용자-여정과-전환)
- [AppsFlyer와 딥링크](#appsflyer와-딥링크)
- [실제 기기·시뮬레이터 검증](#실제-기기시뮬레이터-검증)
- [API Reference](#api-reference)
- [응답과 오류 처리](#응답과-오류-처리)
- [문제 해결과 보안](#문제-해결과-보안)

## 공식 링크

- [SDK 패키지](https://github.com/MobilePartnersCo/AppBoxSDKFramwork)
- [Releases](https://github.com/MobilePartnersCo/AppBoxSDKFramwork/releases)
- [iOS 샘플 앱](https://github.com/MobilePartnersCo/AppBoxSampleiOS)
- [SwiftUI 연동 가이드](https://github.com/MobilePartnersCo/AppBoxSDKFramwork/blob/main/docs/SwiftUI-Integration-Guide.md)
- [AppBox 콘솔 가이드](https://console.appboxapp.com/guide/appbox/%EC%B4%88%EA%B8%B0%20%EC%84%A4%EC%A0%95)
- [AppBox](https://www.appboxapp.com)

샘플 앱은 통합 흐름을 확인하기 위한 참고 자료입니다. 샘플 앱의 의존성 버전과 현재 패키지
태그가 항상 같다고 가정하지 말고, 새 통합에서는 패키지의 Release와 공개 인터페이스를
기준으로 구현하세요.

## 지원 환경

| 항목 | 지원 기준 |
| --- | --- |
| 플랫폼 | iOS 13 이상 |
| 패키지 관리자 | Swift Package Manager |
| Package manifest | Swift tools 5.6 |
| UI framework | UIKit, SwiftUI는 별도 연동 가이드 제공 |
| 언어 | Swift, Objective-C |

최소 Xcode 버전은 고정해서 안내하지 않습니다. 사용할 SDK tag가 요구하는 Swift tools와
iOS SDK를 지원하는 Xcode를 사용하세요.

## Swift Package Manager로 설치

1. Xcode에서 앱 프로젝트를 열고 **Package Dependencies**의 `+`를 선택합니다.

   ![SPM package 추가](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSDKFramwork/main/resource/image/spm1.png)

2. 다음 패키지 URL을 입력합니다.

   ```text
   https://github.com/MobilePartnersCo/AppBoxSDKFramwork
   ```

3. 사용할 버전 규칙을 선택한 뒤 패키지를 추가합니다.

   ![SPM 버전 선택](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSDKFramwork/main/resource/image/spm2.png)

4. `AppBoxSDK`와 `AppBoxPushSDK`를 앱 target에 연결하고, 나머지 선택 기능의 Product를
   필요에 따라 추가합니다.

   ![SPM Product 선택](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSDKFramwork/main/resource/image/spm4.png)

`Lottie`와 `AppsFlyerLib`는 `AppBoxSDK` Product의 전이 의존성입니다. 앱에서 AppBox가
사용하는 기능을 위해 두 패키지를 별도로 설치하지 마세요.

## Product 선택

### 공개 Product와 기술적 의존성

| Product | 선택 기준 | 주요 전이 의존성 |
| --- | --- | --- |
| `AppBoxSDK` | **필수.** AppBox 관리 WebView 또는 고객사 `WKWebView` bridge | Core, WebView, Native In-App, Lottie, AppsFlyer |
| `AppBoxPushSDK` | **필수.** APNs·FCM Push, Notification Service Extension | Core, Firebase Messaging |
| `AppBoxInappMessageSDK` | Native In-App 기능 Product. 일반 서비스 앱에서는 `AppBoxSDK`에 포함되므로 별도로 선택하지 않음 | Core |
| `AppBoxSnsLoginSDK` | Google·Apple·Kakao·Naver 로그인 | Firebase Auth와 각 provider SDK |
| `AppBoxHealthSDK` | HealthKit 걸음 수 | Core |

`AppBoxCoreSDK`, `AppBoxWebViewSDK`, `AppBoxWatermarkSupport`는 내부 모듈입니다. 앱
target에서 직접 선택하거나 import하지 않습니다.

`AppBoxPushSDK`는 `AppBoxSDK`의 직접 의존성이 아니므로 자동으로 추가되지 않습니다.
일반 서비스 앱은 두 Product를 각각 앱 target에 반드시 추가해야 합니다.

### 권장 조합

| 앱 구성 | 권장 Product |
| --- | --- |
| 기본 AppBox 서비스 앱 | `AppBoxSDK` + `AppBoxPushSDK` |
| 고객사 `WKWebView` 연결 | `AppBoxSDK` + `AppBoxPushSDK` |
| SNS 로그인 추가 | 위 조합 + `AppBoxSnsLoginSDK` |
| 걸음 수 추가 | 위 조합 + `AppBoxHealthSDK` |
| Push 이미지 처리 | 앱 target과 NSE target에 `AppBoxPushSDK` |

이 문서의 `AppBox.*` 예제는 일반 서비스 앱을 위한 `AppBoxSDK` 정적 Facade
기준입니다.

## 설정값 준비표

코드를 작성하기 전에 다음 값을 준비합니다. 콘솔 메뉴명은 운영 환경에 따라 달라질 수
있으므로 값이 발급되는 시스템과 완료 조건을 기준으로 확인하세요.

### 설정값의 의미

서로 이름이 비슷한 프로젝트 ID, 앱 ID와 Client ID를 혼용하지 마세요. 다음 표의
`형식·구분`은 값의 종류를 식별하기 위한 설명이며, 예제 문자열을 실제 설정값으로
사용하면 안 됩니다.

| 설정값 | 무엇을 나타내는가 | 형식·구분 |
| --- | --- | --- |
| AppBox project ID | AppBox 콘솔에서 서비스 프로젝트를 식별하는 고유 값입니다. Core 초기화와 Push 서버 설정 조회의 기준으로 사용됩니다. | iOS Bundle ID, Apple Team ID, Firebase Project ID가 아닙니다. 콘솔에 표시된 값을 `<APPBOX_PROJECT_ID>` 전체와 교체합니다. 개발·운영 프로젝트가 분리돼 있다면 현재 앱 환경에 해당하는 값을 사용합니다. |
| HTTPS 서비스 URL | AppBox 관리 WebView가 최초로 로드할 고객사 웹 서비스의 기본 주소입니다. | scheme과 host를 포함한 HTTPS URL을 사용합니다. 예: `https://service.example.com` |
| Firebase 설정 | APNs token을 FCM과 연결하고 Push를 수신하기 위한 Firebase 앱 설정입니다. | 일반적인 자동 설정에서는 개발자가 문자열을 config에 직접 입력하지 않습니다. 기존 `FirebaseApp`을 재사용하거나 AppBox SDK가 project ID와 Bundle ID로 서버 설정을 조회합니다. |
| APNs Auth Key 또는 인증서 | Apple Push Notification service가 앱의 Push 발송 주체를 인증하는 서버 측 credential입니다. | 앱 코드에 입력하는 값이 아닙니다. Push에 사용하는 Firebase 프로젝트와 AppBox 운영 설정에 등록하며 키 파일을 저장소에 커밋하지 않습니다. |
| App Group ID | main app과 Notification Service Extension이 Push queue와 이미지 처리 정보를 공유하는 iOS container 식별자입니다. | Bundle ID 자체가 아니며 `group.` prefix를 사용합니다. 예: `group.com.example.app`. 앱과 NSE에 동일한 값을 설정합니다. |
| Google OAuth Client ID | Google 로그인 요청에서 iOS 앱을 식별하는 OAuth 2.0 Client ID입니다. | Firebase Project ID나 Bundle ID가 아닙니다. Google/Firebase console에서 iOS OAuth Client ID를 확인합니다. Google 로그인을 사용하지 않으면 필요하지 않습니다. |
| Kakao Native App Key | Kakao 네이티브 로그인을 사용할 앱의 플랫폼 키입니다. | REST API Key나 JavaScript Key가 아닌 **Native App Key**를 사용합니다. URL Scheme에는 `kakao<KEY>` 형식으로 적용합니다. |
| Naver Client ID·Secret·URL Scheme | Naver 로그인 애플리케이션을 인증하고 로그인 callback을 앱으로 돌려보내기 위한 값입니다. | Naver 개발자 console에서 같은 애플리케이션에 발급된 Client ID, Client Secret과 등록한 URL Scheme을 한 세트로 사용합니다. |
| AppsFlyer dev key | AppsFlyer SDK가 측정 데이터를 전송할 계정을 식별하는 키입니다. | AppsFlyer dashboard에서 확인하며 실제 값을 저장소나 로그에 남기지 않습니다. |
| Apple App ID | AppsFlyer에 연결할 App Store Connect 앱의 숫자형 식별자입니다. | Bundle ID나 Apple Team ID가 아닙니다. App Store Connect에 표시되는 Apple ID 숫자를 사용합니다. |

### 출처와 적용 위치

| 설정값 | 출처 | 적용 위치 | 필수 조건 | 완료 확인 |
| --- | --- | --- | --- | --- |
| AppBox project ID | AppBox 콘솔의 대상 프로젝트 | `AppBoxCommonConfig.projectId` | 항상 필수 | `result.core.status == INITIALIZED` |
| HTTPS 서비스 URL | 서비스 운영 도메인 또는 AppBox 프로젝트 설정 | `AppBoxWebViewConfig.baseURL` | AppBox 관리 WebView 사용 시 | `AppBox.start` 후 첫 페이지 로드 |
| Firebase 설정 | 기존 Firebase 프로젝트 또는 AppBox project ID 기반 서버 설정 | 앱의 기존 Firebase 초기화 또는 PushSDK 자동 설정 | Push 필수 | `result.push.status == INITIALIZED` 및 FCM token 생성 |
| APNs Auth Key 또는 인증서 | Apple Developer 계정 | Push에 사용하는 Firebase 프로젝트와 AppBox 운영 설정 | 실제 기기 Push | 실제 기기에서 APNs/FCM end-to-end Push 수신 |
| App Group ID | Xcode Signing & Capabilities | 앱 target과 NSE target의 App Groups | NSE queue·이미지 Push 사용 시 | 두 target이 같은 container에 접근 |
| Google OAuth Client ID | Google/Firebase console | `AppBoxPushConfig.firebaseClientID` | Google 로그인 사용 시에만 | Google 로그인 callback 성공 |
| Kakao Native App Key | Kakao Developers | `AppBoxAuthConfig.kakaoNativeAppKey`, URL Types | Kakao 로그인 사용 시 | Kakao 앱/웹 로그인 후 callback 성공 |
| Naver Client ID·Secret·URL Scheme | Naver Developers | `AppBoxAuthConfig`, URL Types | Naver 로그인 사용 시 | Naver 로그인 completion 성공 |
| AppsFlyer dev key | AppsFlyer dashboard | `AppBoxAppsFlyerConfig.devKey` | AppsFlyer 사용 시 | SDK 시작 후 dashboard test device 확인 |
| Apple App ID | App Store Connect | `AppBoxAppsFlyerConfig.appleAppID` | AppsFlyer 사용 시 | AppsFlyer 앱 설정과 bundle ID 일치 |

## 기능별 앱 설정

사용하는 기능의 권한과 Capability만 추가하세요. 모든 권한 키를 일괄로 추가하면 App
Store 심사와 사용자 권한 설명에 불필요한 부담이 생깁니다.

### WebView 기능

| 기능 | Info.plist |
| --- | --- |
| QR·바코드 스캔, 카메라 업로드 | `NSCameraUsageDescription` |
| 위치 조회 | `NSLocationWhenInUseUsageDescription` |
| Face ID 인증 | `NSFaceIDUsageDescription` |
| 외부 앱 실행 | `LSApplicationQueriesSchemes`에 실제 확인할 scheme |
| 연락처 선택 | picker-only 방식이므로 `NSContactsUsageDescription` 불필요 |

서비스 URL은 HTTPS를 사용하세요. `NSAllowsArbitraryLoads = true`를 기본 설정으로
추가하지 않습니다. 불가피한 HTTP 도메인이 있다면 Apple ATS 정책에 따라 필요한
도메인만 예외 처리하세요.

예를 들어 카메라와 위치 기능을 모두 사용할 때만 다음 키를 추가합니다.

```xml
<key>NSCameraUsageDescription</key>
<string>QR 코드와 사진 촬영을 위해 카메라를 사용합니다.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>현재 위치 기반 서비스를 제공하기 위해 위치를 사용합니다.</string>
```

### Push

- 앱 target에 **Push Notifications** Capability를 추가합니다.
- silent Push 또는 백그라운드 처리가 필요하면 **Background Modes**에서
  **Remote notifications**를 활성화합니다.
- `UNUserNotificationCenter.current().delegate`를 앱에서 지정합니다.
- 앱이 이미 `FirebaseApp.configure()`로 Firebase를 초기화했다면 PushSDK는 기존
  `FirebaseApp`을 재사용합니다. AppBox 초기화 전에 기존 Firebase 설정을 완료하세요.
- 기존 Firebase가 없다면 PushSDK가 AppBox project ID와 앱 bundle ID로 서버 설정을
  조회해 Firebase를 초기화합니다.
- `GoogleService-Info.plist`는 앱이 Firebase를 직접 관리할 때만 해당 Firebase 프로젝트
  정책에 따라 추가합니다. PushSDK 자동 설정과 중복으로 Firebase를 초기화하지 마세요.
- Apple Developer에서 발급한 APNs Auth Key 또는 인증서를 Push에 사용하는 Firebase
  프로젝트와 AppBox 운영 설정에 등록합니다. 키 파일과 실제 credential은 저장소에
  포함하지 않습니다.

Background remote notification을 사용할 때의 Info.plist 항목:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### HealthKit

- 앱 target에 **HealthKit** Capability를 추가합니다.
- 걸음 수 읽기에 대한 사용자 설명을 Info.plist에 추가합니다.

```xml
<key>NSHealthShareUsageDescription</key>
<string>걸음 수 정보를 조회하기 위해 건강 데이터 읽기 권한이 필요합니다.</string>
```

현재 걸음 수 기능은 읽기 권한만 요청하므로 `NSHealthUpdateUsageDescription`을 추가하지
않습니다.

### SNS 로그인

- Google: provider console의 reversed client URL scheme을 등록합니다.
- Kakao: `kakao<APP_KEY>` URL scheme과 `kakaokompassauth`, `kakaotalk` query scheme을
  등록합니다.
- Naver: callback URL scheme과 `naversearchapp`, `naversearchthirdlogin` query
  scheme을 등록합니다.
- Apple: 앱 target에 **Sign in with Apple** Capability를 추가합니다.

예시의 모든 값은 provider console의 실제 값으로 교체해야 합니다.

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.&lt;GOOGLE_CLIENT_ID&gt;</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>&lt;NAVER_URL_SCHEME&gt;</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>kakao&lt;KAKAO_APP_KEY&gt;</string>
        </array>
    </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>kakaokompassauth</string>
    <string>kakaotalk</string>
    <string>naversearchapp</string>
    <string>naversearchthirdlogin</string>
</array>
```

### AppsFlyer와 Universal Link

- URI Scheme 딥링크를 사용하면 앱 target의 URL Types에 수신 scheme을 등록합니다.
- Universal Link를 사용하면 **Associated Domains**에 서비스의 `applinks:` domain을
  추가하고 AASA 파일을 구성합니다.
- AppsFlyer `devKey`와 Apple App ID는 코드 설정으로 전달하며 저장소에 실제 값을
  커밋하지 않습니다.
- AppBox SDK는 ATT 권한 팝업을 직접 표시하지 않습니다. IDFA를 사용하는 앱은
  `NSUserTrackingUsageDescription`을 추가하고 앱에서
  `ATTrackingManager.requestTrackingAuthorization`을 호출해야 합니다.
- ATT를 요청하지 않는 앱은 `AppBoxAppsFlyerConfig.attTimeout`을 `0`으로 설정합니다.
  양수 값은 앱이 ATT 권한을 요청하는 동안 AppsFlyer가 기다릴 최대 시간입니다.

ATT를 사용하는 앱에만 다음 키를 추가합니다.

```xml
<key>NSUserTrackingUsageDescription</key>
<string>맞춤형 광고와 성과 측정을 위해 기기 식별자 접근 권한이 필요합니다.</string>
```

## SDK 초기화

앱 시작 지점 한 곳에서 `AppBox.initialize`를 한 번 호출합니다. `core` 성공이 다른 기능의
성공을 의미하지 않으므로 실제로 사용할 모듈의 `status`도 확인하세요.

주요 config:

| Config | 용도 | 필수 여부 |
| --- | --- | --- |
| `AppBoxCommonConfig` | AppBox project ID, debug mode | 필수 |
| `AppBoxWebViewConfig` | AppBox 관리 WebView의 서비스 URL | WebView 사용 시 |
| `AppBoxPushConfig` | Push 및 Google 로그인 관련 설정 | 필수 |
| `AppBoxInAppConfig` | Native In-App 활성화 여부 | 선택, 기본 활성 |
| `AppBoxAuthConfig` | SNS provider 설정 | SNS 로그인 사용 시 |
| `AppBoxAppsFlyerConfig` | AppsFlyer key, Apple App ID, ATT timeout | AppsFlyer 사용 시 |

`AppBoxPushConfig.firebaseClientID`는 Push 전송을 위한 값이 아니라 Firebase Auth 기반
Google 로그인에만 필요한 OAuth Client ID입니다. Google 로그인을 사용하지 않으면
`AppBoxPushConfig()`를 사용하세요.

### Swift

삽입 예제 — `AppDelegate` 또는 앱 coordinator의 시작 메서드에 배치합니다.

<!-- EX-01-SWIFT -->
```swift
import UIKit
import AppBoxSDK

let config = AppBoxInitConfig(
    common: AppBoxCommonConfig(
        projectId: "<APPBOX_PROJECT_ID>",
        debugMode: false
    ),
    webView: AppBoxWebViewConfig(
        baseURL: "https://example.com"
    ),
    push: AppBoxPushConfig(),
    inApp: AppBoxInAppConfig(enabled: true)
)

AppBox.initialize(config) { result in
    guard result.core.status == .INITIALIZED else {
        print(result.core.error?.localizedDescription ?? result.core.message)
        return
    }

    print("webView: \(result.webView.status)")
    print("push: \(result.push.status)")
    print("inApp: \(result.inApp.status)")
}
```

### Objective-C

삽입 예제 — `AppDelegate` 또는 앱 coordinator의 시작 메서드에 배치합니다.

<!-- EX-01-OBJC -->
```objc
@import UIKit;
@import AppBoxSDK;

AppBoxCommonConfig *common =
    [[AppBoxCommonConfig alloc] initWithProjectId:@"<APPBOX_PROJECT_ID>"
                                        debugMode:NO];
AppBoxWebViewConfig *webView =
    [[AppBoxWebViewConfig alloc]
        initWithBaseURL:@"https://example.com"
              webConfig:[[AppBoxWebConfig alloc] init]];
AppBoxPushConfig *push = [[AppBoxPushConfig alloc] init];
AppBoxInAppConfig *inApp =
    [[AppBoxInAppConfig alloc] initWithEnabled:YES];

AppBoxInitConfig *config =
    [[AppBoxInitConfig alloc] initWithCommon:common
                                    webView:webView
                                       push:push
                                      inApp:inApp
                                       auth:nil
                                 appsFlyer:nil
                      initializationTimeout:30];

[AppBox initializeWithConfig:config completion:^(AppBoxInitResult *result) {
    if (result.core.status != AppBoxInitStatusINITIALIZED) {
        NSLog(@"%@", result.core.error.localizedDescription ?: result.core.message);
        return;
    }

    NSLog(@"webView=%ld push=%ld inApp=%ld",
          (long)result.webView.status,
          (long)result.push.status,
          (long)result.inApp.status);
}];
```

초기화 상태는 다음과 같습니다.

| 상태 | 의미 |
| --- | --- |
| `INITIALIZED` | 해당 모듈 초기화 성공 |
| `SKIPPED` | Product 또는 config를 사용하지 않아 건너뜀 |
| `FAILED` | 해당 모듈 초기화 실패. `error`와 `message` 확인 |

같은 설정으로 초기화가 진행 중이면 작업을 공유합니다. 완료된 설정과 다른 config로 다시
초기화하면 `conflictingInitialization` 오류가 발생할 수 있습니다.

## AppBox 관리 화면

`webView` 모듈 초기화가 성공한 뒤 UI를 표시할 수 있는 view controller에서 시작합니다.
`success == true`는 화면 시작 요청을 전달했다는 의미이며 웹 페이지 로딩 완료를 뜻하지
않습니다.

### Swift

삽입 예제 — AppBox를 표시할 `UIViewController` 메서드에 배치합니다.

<!-- EX-02-SWIFT -->
```swift
AppBox.preloadWebView { loaded in
    print("preload: \(loaded)")
}

AppBox.start(from: self) { success, error in
    if !success {
        print(error?.localizedDescription ?? "AppBox 화면 시작 실패")
    }
}
```

### Objective-C

삽입 예제 — AppBox를 표시할 `UIViewController` 메서드에 배치합니다.

<!-- EX-02-OBJC -->
```objc
[AppBox preloadWebViewWithCompletion:^(BOOL loaded) {
    NSLog(@"preload=%@", loaded ? @"YES" : @"NO");
}];

[AppBox startFrom:self completion:^(BOOL success, NSError *error) {
    if (!success) {
        NSLog(@"%@", error.localizedDescription ?: @"AppBox 화면 시작 실패");
    }
}];
```

화면 외관과 동작은 필요할 때 다음 정적 함수로 설정할 수 있습니다.

### Swift

삽입 예제 — 초기화 후 화면 표시 전에 호출합니다.

<!-- EX-03-SWIFT -->
```swift
AppBox.setIndicatorEnabled(true)
AppBox.setPullDownRefresh(true)
AppBox.setSystemBarAppearance(
    backgroundHex: "#1F124C",
    style: .light
)
```

### Objective-C

삽입 예제 — 초기화 후 화면 표시 전에 호출합니다.

<!-- EX-03-OBJC -->
```objc
[AppBox setIndicatorEnabled:YES];
[AppBox setPullDownRefreshUsed:YES];
[AppBox setSystemBarAppearanceWithBackgroundHex:@"#1F124C"
                                          style:AppBoxSystemBarStyleLight];
```

SwiftUI 앱은 `@UIApplicationDelegateAdaptor`와 UIKit 화면 adapter가 필요합니다.
[SwiftUI 연동 가이드](https://github.com/MobilePartnersCo/AppBoxSDKFramwork/blob/main/docs/SwiftUI-Integration-Guide.md)를
확인하세요.

## 고객사 WKWebView 연결

앱에서 직접 소유하는 `WKWebView`를 유지하면서 AppBox bridge를 연결할 수 있습니다.
연결한 동일 인스턴스를 화면 폐기 시 반드시 해제하세요.

### Swift

완성 예제 — 고객사 WebView를 소유하는 `UIViewController`입니다.

<!-- EX-04-SWIFT -->
```swift
import UIKit
import WebKit
import AppBoxSDK

final class CustomerWebViewController: UIViewController, WKNavigationDelegate {
    private let webView = WKWebView()

    override func viewDidLoad() {
        super.viewDidLoad()

        AppBox.attachWebView(webView)
        AppBox.attachNavigationObservation(webView, forwardingTo: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppBox.setActiveWebView(webView)
    }

    override func viewDidDisappear(_ animated: Bool) {
        AppBox.clearActiveWebView(webView)
        super.viewDidDisappear(animated)
    }

    deinit {
        AppBox.detachNavigationObservation(webView)
        AppBox.detachWebView(webView)
    }
}
```

### Objective-C

완성 예제 — 고객사 WebView를 소유하는 `UIViewController`입니다.

<!-- EX-04-OBJC -->
```objc
@import UIKit;
@import WebKit;
@import AppBoxSDK;

@interface CustomerWebViewController : UIViewController <WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@end

@implementation CustomerWebViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.webView = [[WKWebView alloc] init];
    [AppBox attachWebView:self.webView];
    [AppBox attachNavigationObservation:self.webView forwardingTo:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [AppBox setActiveWebView:self.webView];
}

- (void)viewDidDisappear:(BOOL)animated {
    [AppBox clearActiveWebView:self.webView];
    [super viewDidDisappear:animated];
}

- (void)dealloc {
    [AppBox detachNavigationObservation:self.webView];
    [AppBox detachWebView:self.webView];
}

@end
```

Navigation 관찰은 선택 사항입니다. 앱에서 이후 `navigationDelegate`를 직접 교체하면 SDK
proxy 연결이 끊길 수 있습니다. 여러 WebView를 한 번에 폐기할 때만
`AppBox.detachAllWebViews()`를 사용하세요.

## Push lifecycle

Push 권한 요청, APNs 등록, token 전달은 각각 다른 단계입니다.

1. `AppBoxInitResult.push.status == INITIALIZED`인지 확인합니다.
2. 사용자에게 알림 권한을 요청합니다.
3. 권한이 허용되면 APNs 등록을 요청합니다.
4. AppDelegate가 받은 원본 APNs token을 전달합니다.
5. foreground, background, click callback을 각각 한 번 전달합니다.

`registerForRemoteNotifications()`, `handleAPNSToken(_:)`,
`handleForegroundNotification(_:)`의 `Bool`은 SDK runtime에 요청을 전달했는지 나타냅니다.
APNs 등록, token 저장 또는 서버 전송 완료를 의미하지 않습니다.

### Swift

완성 예제 — 앱의 `AppDelegate.swift`에 적용합니다.

<!-- EX-05-SWIFT -->
```swift
import UIKit
@preconcurrency import UserNotifications
import AppBoxSDK

@main
final class AppDelegate: UIResponder,
                         UIApplicationDelegate,
                         @preconcurrency UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        let config = AppBoxInitConfig(
            common: AppBoxCommonConfig(
                projectId: "<APPBOX_PROJECT_ID>",
                debugMode: false
            ),
            webView: AppBoxWebViewConfig(
                baseURL: "https://example.com"
            ),
            push: AppBoxPushConfig()
        )

        AppBox.initialize(config) { result in
            guard result.push.status == .INITIALIZED else { return }

            AppBox.requestPushPermission { granted, error in
                guard granted, error == nil else { return }
                _ = AppBox.registerForRemoteNotifications()
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        _ = AppBox.handleAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        AppBox.handleRemoteNotification(userInfo: userInfo)
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        _ = AppBox.handleForegroundNotification(notification.request)
        completionHandler([.badge, .alert, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        AppBox.movePush(response)
        completionHandler()
    }
}
```

### Objective-C

완성 예제 — 앱의 `AppDelegate.m`에 적용합니다.

<!-- EX-05-OBJC -->
```objc
@import UIKit;
@import UserNotifications;
@import AppBoxSDK;

@interface AppDelegate : UIResponder
    <UIApplicationDelegate, UNUserNotificationCenterDelegate>
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;

    AppBoxCommonConfig *common =
        [[AppBoxCommonConfig alloc] initWithProjectId:@"<APPBOX_PROJECT_ID>"
                                            debugMode:NO];
    AppBoxWebViewConfig *webView =
        [[AppBoxWebViewConfig alloc]
            initWithBaseURL:@"https://example.com"
                  webConfig:[[AppBoxWebConfig alloc] init]];
    AppBoxInitConfig *config =
        [[AppBoxInitConfig alloc] initWithCommon:common
                                        webView:webView
                                           push:[[AppBoxPushConfig alloc] init]
                                          inApp:[[AppBoxInAppConfig alloc] init]
                                           auth:nil
                                     appsFlyer:nil
                          initializationTimeout:30];

    [AppBox initializeWithConfig:config completion:^(AppBoxInitResult *result) {
        if (result.push.status != AppBoxInitStatusINITIALIZED) {
            return;
        }

        [AppBox requestPushPermissionWithCompletion:
            ^(BOOL granted, NSError *error) {
                if (granted && error == nil) {
                    [AppBox registerForRemoteNotifications];
                }
            }];
    }];
    return YES;
}

- (void)application:(UIApplication *)application
        didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [AppBox handleAPNSToken:deviceToken];
}

- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
        fetchCompletionHandler:
            (void (^)(UIBackgroundFetchResult result))completionHandler {
    [AppBox handleRemoteNotificationUserInfo:userInfo];
    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:
            (void (^)(UNNotificationPresentationOptions options))completionHandler {
    [AppBox handleForegroundNotification:notification.request];
    completionHandler(
        UNNotificationPresentationOptionBadge |
        UNNotificationPresentationOptionAlert |
        UNNotificationPresentationOptionSound
    );
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    [AppBox movePushWithResponse:response];
    completionHandler();
}

@end
```

OS 알림 권한과 서비스의 마케팅 Push 수신 동의는 별도 상태입니다. 서비스 동의를 저장할 때는
token이 준비된 뒤 `savePushToken(_:pushEnabled:completion:)`을 사용하세요. APNs·Firebase
token과 전체 Push payload는 로그나 분석 도구에 남기지 않습니다.

`movePush(_:)`는 알림 클릭 callback에서 한 번만 호출합니다.

| payload 조건 | 동작 | 선행 조건 |
| --- | --- | --- |
| `touchOpenType = "url"` | `param` URL을 AppBox 화면 이동 경로로 전달 | 유효한 `param`, `idx`, 초기화된 WebView |
| `touchOpenType = "inapp"` | Native In-App handler 또는 WebView In-App bridge로 전달 | In-App runtime 또는 준비된 AppBox WebView |
| 그 외 또는 필수 값 누락 | 클릭·전환 이력만 처리하고 별도 화면 이동을 생략할 수 있음 | Push runtime 초기화 |

화면이 아직 준비되지 않은 상태의 In-App 클릭은 SDK가 보류했다가 WebView 준비 후 전달할 수
있습니다. 앱에서 같은 `UNNotificationResponse`를 AppDelegate와 SceneDelegate 양쪽에
중복 전달하지 마세요.

## Notification Service Extension

Push 이미지와 수신 queue를 사용하는 경우 앱 target과 NSE target에 같은 App Group을
활성화하고 NSE target에도 `AppBoxPushSDK`를 연결합니다.

기본 App Group은 bundle ID로 결정됩니다.

- 앱 target: `group.<APP_BUNDLE_ID>`
- NSE bundle ID가 정확히 `<APP_BUNDLE_ID>.NotificationService`로 끝나는 경우:
  `group.<APP_BUNDLE_ID>`
- 다른 NSE bundle ID 규칙을 사용하면 자동 추론에 의존하지 말고 앱과 NSE의
  `Info.plist`에 같은 `AppBoxAppGroupIdentifier`를 지정하거나, queue API 호출 전에
  `configureAppGroupIdentifier`로 같은 값을 전달합니다.

```xml
<key>AppBoxAppGroupIdentifier</key>
<string>group.com.example.app</string>
```

서버 Push payload의 `aps.mutable-content`가 `1`이어야 NSE가 실행됩니다.

```json
{
  "aps": {
    "alert": {
      "title": "Title",
      "body": "Body"
    },
    "mutable-content": 1
  }
}
```

### Swift

완성 예제 — NSE target의 `NotificationService.swift`입니다.

<!-- EX-06-SWIFT -->
```swift
import UserNotifications
import AppBoxPushSDK

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent =
            request.content.mutableCopy() as? UNMutableNotificationContent

        // 기본 bundle ID 규칙을 사용하지 않을 때만 queue API보다 먼저 호출합니다.
        // AppBoxPush.shared.configureAppGroupIdentifier("group.com.example.app")
        AppBoxPush.shared.recordNotificationReceived(request)
        AppBoxPush.shared.recordJourneyPushReceived(request)
        AppBoxPush.shared.recordPushDelivered(request)
        AppBoxPush.shared.createFCMImage(
            request,
            withContentHandler: contentHandler
        )
    }

    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler, let bestAttemptContent else { return }
        contentHandler(bestAttemptContent)
    }
}
```

### Objective-C

완성 예제 — NSE target의 `NotificationService.m`입니다.

<!-- EX-06-OBJC -->
```objc
@import UserNotifications;
@import AppBoxPushSDK;

@interface NotificationService : UNNotificationServiceExtension
@property (nonatomic, copy) void (^contentHandler)(UNNotificationContent *);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;
@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                    withContentHandler:
                        (void (^)(UNNotificationContent *content))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];

    // 기본 bundle ID 규칙을 사용하지 않을 때만 queue API보다 먼저 호출합니다.
    // [[AppBoxPush shared] configureAppGroupIdentifier:@"group.com.example.app"];
    [[AppBoxPush shared] recordNotificationReceived:request];
    [[AppBoxPush shared] recordJourneyPushReceived:request];
    [[AppBoxPush shared] recordPushDeliveredWithRequest:request];
    [[AppBoxPush shared] createFCMImage:request
                    withContentHandler:contentHandler];
}

- (void)serviceExtensionTimeWillExpire {
    if (self.contentHandler != nil && self.bestAttemptContent != nil) {
        self.contentHandler(self.bestAttemptContent);
    }
}

@end
```

- `recordNotificationReceived`는 수신 Push를 App Group queue에 기록합니다.
- `recordJourneyPushReceived`는 Push 수신 여정을 기록합니다.
- `recordPushDelivered`는 Push 도달 통계를 기록합니다.
- `createFCMImage`는 payload의 이미지를 attachment로 구성하고 content handler를
  호출합니다.
- `serviceExtensionTimeWillExpire`에서는 원본에 가까운 content를 전달해 알림 누락을
  방지합니다.
- 동일한 Push의 queue 기록 함수를 main app과 NSE에서 중복 호출하지 마세요.
- 앱과 NSE의 App Group Capability 및 override 값은 반드시 같아야 합니다. 값이 다르면
  Extension queue를 앱이 가져올 수 없습니다.

## Native In-App

Native In-App은 Product 포함 여부, 초기화 결과, 표시 가능한 화면 상태를 각각 확인해야
합니다. 메시지를 표시할 화면의 진입과 이탈 호출은 항상 짝을 맞추세요.

### Swift

완성 예제 — In-App을 표시할 `UIViewController`입니다.

<!-- EX-07-SWIFT -->
```swift
import UIKit
import AppBoxSDK

final class InAppViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        guard AppBox.isInAppAvailable() else { return }

        AppBox.syncInApp { success, error in
            if !success {
                print(error?.localizedDescription ?? "In-App 동기화 실패")
            }
        }

        AppBox.setInAppActionListener { event in
            if event.action == "function" {
                print(event.actionValue)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppBox.enterInAppDisplayScreen(delay: 0.3)
    }

    override func viewDidDisappear(_ animated: Bool) {
        AppBox.leaveInAppDisplayScreen()
        super.viewDidDisappear(animated)
    }
}
```

### Objective-C

완성 예제 — In-App을 표시할 `UIViewController`입니다.

<!-- EX-07-OBJC -->
```objc
@import UIKit;
@import AppBoxSDK;

@interface InAppViewController : UIViewController
@end

@implementation InAppViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    if (![AppBox isInAppAvailable]) {
        return;
    }

    [AppBox syncInAppWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            NSLog(@"%@", error.localizedDescription ?: @"In-App 동기화 실패");
        }
    }];

    [AppBox setInAppActionListener:^(AppBoxInAppActionEvent *event) {
        if ([event.action isEqualToString:@"function"]) {
            NSLog(@"%@", event.actionValue);
        }
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [AppBox enterInAppDisplayScreenWithDelay:0.3];
}

- (void)viewDidDisappear:(BOOL)animated {
    [AppBox leaveInAppDisplayScreen];
    [super viewDidDisappear:animated];
}

@end
```

특정 캠페인은 `showInAppCampaign(_:completion:)`으로 요청할 수 있습니다. 성공값은 메시지가
표시됐거나 표시 대기열에 들어갔다는 의미입니다. listener는 액션 통지용이며 `link`와
`external` URL은 SDK가 계속 처리하므로 앱에서 다시 열지 마세요. 더 이상 액션 통지가
필요하지 않으면 `AppBox.setInAppActionListener(nil)`로 listener를 해제하세요.

## SNS 로그인

`AppBoxSnsLoginSDK`를 추가하고 초기화 config에 사용할 provider 설정을 전달합니다.
Provider별 URL Scheme, Capability와 외부 console 설정도 함께 완료해야 합니다.

다음 coordinator는 앱 시작 시 `initialize()`를 한 번 호출하고, 로그인 버튼을 누를 때
`signInWithKakao(from:)`를 호출하는 예시입니다. Auth 초기화가 성공하기 전에는 로그인을
시작하지 않습니다.

### Swift

완성 예제 — 앱 시작과 로그인 화면에서 공유할 coordinator입니다.

<!-- EX-08-SWIFT -->
```swift
import UIKit
import WebKit
import AppBoxSDK

final class AppBoxCoordinator {
    private(set) var authReady = false
    weak var naverWebView: WKWebView?

    func initialize() {
        let auth = AppBoxAuthConfig(
            googleEnabled: false,
            appleEnabled: false,
            kakaoNativeAppKey: "<KAKAO_NATIVE_APP_KEY>",
            naverAppName: "AppBox",
            naverClientId: "<NAVER_CLIENT_ID>",
            naverClientSecret: "<NAVER_CLIENT_SECRET>",
            naverURLScheme: "<NAVER_URL_SCHEME>"
        )
        let config = AppBoxInitConfig(
            common: AppBoxCommonConfig(projectId: "<APPBOX_PROJECT_ID>"),
            webView: AppBoxWebViewConfig(baseURL: "https://example.com"),
            push: AppBoxPushConfig(),
            auth: auth
        )

        AppBox.initialize(config) { [weak self] result in
            self?.authReady = result.auth.status == .INITIALIZED
        }
    }

    func signInWithKakao(from viewController: UIViewController) {
        guard authReady else { return }

        AppBox.signIn(.kakao, presentingViewController: viewController) {
            user, error in
            guard let user, error == nil else { return }
            print("login completed: \(user.uid.isEmpty == false)")
        }
    }

    func signInWithNaver(callId: String? = nil) {
        guard authReady, let naverWebView else { return }

        AppBox.signInWithNaver(webView: naverWebView, callId: callId) {
            user, error in
            guard user != nil, error == nil else { return }
            print("Naver login completed")
        }
    }
}
```

### Objective-C

완성 예제 — 앱 시작과 로그인 화면에서 공유할 coordinator입니다.

<!-- EX-08-OBJC -->
```objc
@import UIKit;
@import WebKit;
@import AppBoxSDK;

@interface AppBoxCoordinator : NSObject
@property (nonatomic, assign, readonly, getter=isAuthReady) BOOL authReady;
@property (nonatomic, weak) WKWebView *naverWebView;
- (void)initializeAppBox;
- (void)signInWithKakaoFromViewController:(UIViewController *)viewController;
- (void)signInWithNaverWithCallId:(NSString *)callId;
@end

@interface AppBoxCoordinator ()
@property (nonatomic, assign, readwrite, getter=isAuthReady) BOOL authReady;
@end

@implementation AppBoxCoordinator

- (void)initializeAppBox {
    AppBoxAuthConfig *auth =
        [[AppBoxAuthConfig alloc]
            initWithGoogleEnabled:NO
                     appleEnabled:NO
         kakaoNativeAppKey:@"<KAKAO_NATIVE_APP_KEY>"
               naverAppName:@"AppBox"
              naverClientId:@"<NAVER_CLIENT_ID>"
          naverClientSecret:@"<NAVER_CLIENT_SECRET>"
               naverURLScheme:@"<NAVER_URL_SCHEME>"];
    AppBoxCommonConfig *common =
        [[AppBoxCommonConfig alloc] initWithProjectId:@"<APPBOX_PROJECT_ID>"
                                            debugMode:NO];
    AppBoxWebViewConfig *webView =
        [[AppBoxWebViewConfig alloc]
            initWithBaseURL:@"https://example.com"
                  webConfig:[[AppBoxWebConfig alloc] init]];
    AppBoxInitConfig *config =
        [[AppBoxInitConfig alloc] initWithCommon:common
                                        webView:webView
                                           push:[[AppBoxPushConfig alloc] init]
                                          inApp:[[AppBoxInAppConfig alloc] init]
                                           auth:auth
                                     appsFlyer:nil
                          initializationTimeout:30];

    __weak typeof(self) weakSelf = self;
    [AppBox initializeWithConfig:config completion:^(AppBoxInitResult *result) {
        weakSelf.authReady =
            result.auth.status == AppBoxInitStatusINITIALIZED;
    }];
}

- (void)signInWithKakaoFromViewController:(UIViewController *)viewController {
    if (!self.isAuthReady) {
        return;
    }

    [AppBox signInWithProvider:AppBoxAuthProviderKakao
     presentingViewController:viewController
                    completion:
                        ^(AppBoxUserAuthData *user, NSError *error) {
        if (user != nil && error == nil) {
            NSLog(@"login completed");
        }
    }];
}

- (void)signInWithNaverWithCallId:(NSString *)callId {
    if (!self.isAuthReady || self.naverWebView == nil) {
        return;
    }

    [AppBox signInWithNaverWebView:self.naverWebView
                           callId:callId
                       completion:
        ^(AppBoxUserAuthData *user, NSError *error) {
            if (user != nil && error == nil) {
                NSLog(@"Naver login completed");
            }
        }];
}

@end
```

- `getAuthProviderDescriptors()`의 `configured`로 provider별 설정 여부를 확인합니다.
- `isAuthAvailable(_:)`은 runtime 포함 여부이며 provider 설정 완료 여부가 아닙니다.
- Naver 로그인은 일반 `signIn(_:presentingViewController:)`가 아니라
  `signInWithNaver(webView:callId:completion:)`을 사용합니다. `webView`는 로그인 요청을
  시작한 AppBox 또는 고객사 WebView이며 `callId`는 웹 요청과 응답을 연결할 때 전달하고,
  Native UI에서 직접 시작하면 `nil`을 사용할 수 있습니다.
- 로그아웃은 `signOut(_:completion:)`을 사용합니다.
- Google 로그인을 사용하면 `AppBoxPushConfig(firebaseClientID:)`에 provider console의
  OAuth Client ID를 전달합니다.
- 사용자 정보와 provider token을 로그에 남기지 않습니다.

## HealthKit

`AppBoxHealthSDK`와 HealthKit Capability를 추가한 뒤, 사용자가 걸음 수 기능을 선택한
시점에 조회합니다. 별도의 Health 권한 요청 함수는 없으며 조회 함수가 필요한 읽기 권한을
요청합니다.

### Swift

완성 예제 — 걸음 수를 사용하는 `UIViewController`입니다.

<!-- EX-09-SWIFT -->
```swift
import UIKit
import AppBoxSDK

final class HealthViewController: UIViewController {
    private var latestSteps: [AppBoxDailyStep] = []

    func loadHealthSteps() {
        guard AppBox.isHealthAvailable() else { return }

        AppBox.getHealthSteps(
            fromDate: "2026-07-01",
            toDate: "2026-07-07"
        ) { steps, error in
            if let error {
                let code = AppBoxHealthErrorCode(rawValue: error.code) ?? .unknown
                print("Health error: \(code)")
                return
            }

            self.latestSteps = steps ?? []
        }
    }
}
```

### Objective-C

완성 예제 — 걸음 수를 사용하는 `UIViewController`입니다.

<!-- EX-09-OBJC -->
```objc
@import UIKit;
@import AppBoxSDK;

@interface HealthViewController : UIViewController
@property (nonatomic, copy) NSArray<AppBoxDailyStep *> *latestSteps;
@end

@implementation HealthViewController

- (void)loadHealthSteps {
    if (![AppBox isHealthAvailable]) {
        return;
    }

    [AppBox getHealthStepsFromDate:@"2026-07-01"
                            toDate:@"2026-07-07"
                        completion:
                            ^(NSArray<AppBoxDailyStep *> *steps, NSError *error) {
        if (error != nil) {
            AppBoxHealthErrorCode code = (AppBoxHealthErrorCode)error.code;
            NSLog(@"Health error: %ld", (long)code);
            return;
        }

        self.latestSteps = steps ?: @[];
    }];
}

@end
```

날짜 형식은 `yyyy-MM-dd`이며 시작일과 종료일을 모두 포함합니다. HealthKit 권한 상태와
runtime 포함 여부는 서로 다릅니다. 건강 데이터는 필요한 기간만 조회하고 로그나 분석
도구에 기록하지 마세요.

## 사용자 여정과 전환

콘솔에 정의한 event key와 conversion code를 사용합니다. 같은 사용자 행동에 대해 중복
호출하지 마세요.

### Swift

삽입 예제 — 실제 사용자 행동이 완료되는 앱 이벤트 메서드에 배치합니다.

<!-- EX-10-SWIFT -->
```swift
AppBox.trackJourneyEvent("product_view")

AppBox.trackConversion("<CONVERSION_CODE>") { success, error in
    if !success {
        print(error?.localizedDescription ?? "전환 기록 실패")
    }
}

let deviceUserId = AppBox.getDeviceUserId()
```

### Objective-C

삽입 예제 — 실제 사용자 행동이 완료되는 앱 이벤트 메서드에 배치합니다.

<!-- EX-10-OBJC -->
```objc
[AppBox trackJourneyEvent:@"product_view"];

[AppBox trackConversion:@"<CONVERSION_CODE>"
              completion:^(BOOL success, NSError *error) {
    if (!success) {
        NSLog(@"%@", error.localizedDescription ?: @"전환 기록 실패");
    }
}];

NSString *deviceUserId = [AppBox getDeviceUserId];
```

`deviceUserId`는 서비스 회원 ID나 광고 식별자가 아닙니다. 인증·권한 판단에 사용하거나
불필요하게 로그에 남기지 마세요.

## AppsFlyer와 딥링크

AppsFlyer를 사용할 때는 listener 또는 JavaScript bridge를 먼저 준비하고
`startAppsFlyer()`를 앱 lifecycle에서 한 번 호출합니다.

### Swift

삽입 예제 — `AppDelegate`의 SDK 설정 단계에 배치하고 앱 lifecycle에서 한 번 시작합니다.

<!-- EX-11-SWIFT -->
```swift
let appsFlyer = AppBoxAppsFlyerConfig(
    devKey: "<APPSFLYER_DEV_KEY>",
    appleAppID: "<APPLE_APP_ID>",
    attTimeout: 0
)
AppBox.configureAppsFlyer(appsFlyer)

AppBox.setAppsFlyerDeepLinkListener { result in
    switch result.status {
    case .found:
        print("AppsFlyer deep link received")
    case .notFound:
        break
    case .error:
        print("AppsFlyer deep link error")
    @unknown default:
        break
    }
}

let bridge = AppBoxAppsFlyerJavaScriptBridgeConfig(
    deliverNotFoundAndError: false,
    pendingLimit: 10
)
AppBox.configureAppsFlyerJavaScriptBridge(bridge)
AppBox.startAppsFlyer()
```

### Objective-C

삽입 예제 — `AppDelegate`의 SDK 설정 단계에 배치하고 앱 lifecycle에서 한 번 시작합니다.

<!-- EX-11-OBJC -->
```objc
AppBoxAppsFlyerConfig *appsFlyer =
    [[AppBoxAppsFlyerConfig alloc]
        initWithDevKey:@"<APPSFLYER_DEV_KEY>"
            appleAppID:@"<APPLE_APP_ID>"
            attTimeout:0];
[AppBox configureAppsFlyerWithConfig:appsFlyer];

[AppBox setAppsFlyerDeepLinkListener:
    ^(AppBoxAppsFlyerDeepLinkResult *result) {
        if (result.status == AppBoxAppsFlyerDeepLinkStatusFound) {
            NSLog(@"AppsFlyer deep link received");
        }
    }];

AppBoxAppsFlyerJavaScriptBridgeConfig *bridge =
    [[AppBoxAppsFlyerJavaScriptBridgeConfig alloc]
        initWithDeliverNotFoundAndError:NO
                           pendingLimit:10];
[AppBox configureAppsFlyerJavaScriptBridgeWithConfig:bridge];
[AppBox startAppsFlyer];
```

앱이 수신한 URL Scheme과 Universal Link는 lifecycle callback의 원본 값을 전달합니다.
AppDelegate와 SceneDelegate에서 같은 callback을 중복 전달하지 마세요.

### Swift

삽입 예제 — `AppDelegate` 또는 대응하는 `SceneDelegate` callback에 배치합니다.

<!-- EX-12-SWIFT -->
```swift
func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
) -> Bool {
    AppBox.handleURL(url, options: options)
}

func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
) -> Bool {
    AppBox.handleUserActivity(userActivity)
}
```

### Objective-C

삽입 예제 — `AppDelegate` callback에 배치합니다.

<!-- EX-12-OBJC -->
```objc
- (BOOL)application:(UIApplication *)application
             openURL:(NSURL *)url
             options:
                (NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    return [AppBox handleURL:url options:options];
}

- (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
 restorationHandler:
    (void (^)(NSArray<id<UIUserActivityRestoring>> *objects))restorationHandler {
    return [AppBox handleUserActivity:userActivity];
}
```

Native listener는 `clearAppsFlyerDeepLinkListener()`, JavaScript bridge는
`clearAppsFlyerJavaScriptBridge()`로 각각 해제할 수 있습니다.
`result.value`, `subParams`, `rawParams`와 전체 URL은 로그·crash report·분석 도구에
그대로 기록하지 마세요.

## 실제 기기·시뮬레이터 검증

아래 표는 SDK 배포 결과가 아니라 **연동 개발자가 직접 수행해야 하는 검증
시나리오**입니다. APNs, SNS provider, HealthKit과 실제 딥링크는 credential과 서명된
실제 기기가 필요합니다.

| 시나리오 | 사전 조건 | 조작 | 기대 결과 | 환경 | 첫 실패 점검 |
| --- | --- | --- | --- | --- | --- |
| 최초 알림 권한 | 앱 삭제 또는 알림 권한 초기화 | 앱 실행 후 권한 허용 | 권한 callback 성공 후 APNs 등록 요청 | 실제 기기 | Push Capability, 권한 요청 시점 |
| APNs·FCM token | APNs 키와 Firebase/AppBox 설정 완료 | 앱 실행 후 token callback 대기 | APNs token 전달 및 FCM token 생성 | 실제 기기 | bundle ID, aps-environment, Firebase project |
| 서버 Push | 유효한 대상 token | AppBox 운영 환경에서 테스트 Push 발송 | 기기에 알림 표시 | 실제 기기 | token 환경, APNs 키, Push 수신 동의 |
| foreground Push | 앱이 전면 상태 | 테스트 Push 발송 | delegate 호출 및 지정한 표시 옵션 적용 | 실제 기기 | notification center delegate, 중복 callback |
| background·종료 Push | 앱을 background 또는 종료 상태로 전환 | 테스트 Push 발송 | 알림 표시 후 클릭 callback 수신 | 실제 기기 | payload `aps`, Background Modes |
| Push 클릭·`movePush` | `url` 또는 `inapp` payload 준비 | 알림 클릭 | payload 유형에 맞는 화면 또는 In-App 처리 | 실제 기기 | `touchOpenType`, `param`, `idx`, WebView 준비 |
| 이미지 Push·NSE | NSE와 `mutable-content: 1` payload | 이미지 Push 발송 | 이미지 attachment가 포함된 알림 표시 | 실제 기기 | NSE Product 연결, deployment target, image URL |
| App Group queue | 앱과 NSE에 같은 App Group | NSE 실행 후 앱 진입 | Extension 기록을 앱이 import·drain | 실제 기기 | bundle ID suffix, entitlement, override 값 |
| SNS 로그인 | provider console·URL Scheme 설정 완료 | Google·Kakao·Naver·Apple 로그인 | provider 인증 후 `AppBox.handleURL` 또는 completion 성공 | 실제 기기 권장 | provider key, callback scheme, 중복 URL 전달 |
| HealthKit | Capability와 읽기 설명 추가 | 걸음 수 조회 실행 후 권한 허용 | `yyyy-MM-dd` 범위의 결과 또는 정의된 오류 | 실제 기기 | Health 사용 가능 여부, 읽기 권한, 날짜 범위 |
| URL Scheme | 앱 URL Types 등록 | 등록한 scheme URL 열기 | `AppBox.handleURL`이 처리 결과 반환 | 실제 기기·시뮬레이터 | callback 위치, options 보존, 중복 전달 |
| Universal Link | Associated Domains와 AASA 배포 | HTTPS link 탭 | `AppBox.handleUserActivity` 호출 | 실제 기기 | AASA content type·경로·Team ID |
| AppsFlyer deep link | AppsFlyer test device와 link 설정 | 테스트 link 실행 | listener 또는 JavaScript bridge에 한 번 전달 | 실제 기기 | configure 순서, `startAppsFlyer`, WebView ready |
| 기본 화면 smoke | project ID와 HTTPS URL 준비 | 초기화 후 `AppBox.start` | AppBox 첫 화면 로드 | 실제 기기·시뮬레이터 | `core`·`webView` status, ATS, URL |

기능별 완료 체크:

- [ ] `core`, `webView`, `push` 초기화 결과를 각각 확인했다.
- [ ] 앱과 NSE가 동일한 App Group을 사용한다.
- [ ] foreground, background, 종료 상태 Push를 각각 확인했다.
- [ ] AppDelegate와 SceneDelegate에서 같은 URL·Push callback을 중복 전달하지 않는다.
- [ ] 실제 token, payload, 인증 정보, 건강 데이터와 deep-link 원문을 로그에 남기지 않는다.
- [ ] 사용하지 않는 권한 키와 Capability를 추가하지 않았다.

## API Reference

README는 최초 설치와 lifecycle 통합에 필요한 대표 함수만 안내합니다. 전체 함수의
parameter, request, response, 오류와 플랫폼별 세부 계약은 AppBox 콘솔 개발자 센터의
함수 레퍼런스가 담당합니다. 공개 URL이 확정되기 전에는 이 문서에 임시 링크를 추가하지
않습니다.

| 기능군 | 공개 함수 |
| --- | --- |
| 초기화·화면 | `initialize`, `start`, `preloadWebView`, `setBaseURL`, `setDebugMode` |
| 화면 설정 | `setIndicatorEnabled`, `setLoadingData`, `setSystemBarAppearance`, `setPullDownRefresh`, `setIntro`, `setDemoDelegate` |
| 고객 WebView | `attachWebView`, `detachWebView`, `detachAllWebViews`, `setActiveWebView`, `clearActiveWebView`, `attachNavigationObservation`, `detachNavigationObservation`, `sendDebugPingToActiveWebView` |
| Push lifecycle | `isPushAvailable`, `requestPushPermission`, `registerForRemoteNotifications`, `handleAPNSToken`, `handleRemoteNotification`, `handleForegroundNotification`, `movePush` |
| Push 데이터 | `getPushToken`, `savePushToken`, `setPushSegment`, `subscribeTopic`, `unsubscribeTopic` |
| Native In-App | `isInAppAvailable`, `syncInApp`, `enterInAppDisplayScreen`, `leaveInAppDisplayScreen`, `showInAppCampaign`, `setInAppActionListener` |
| 사용자 이벤트 | `trackJourneyEvent`, `trackConversion`, `getDeviceUserId` |
| SNS 로그인 | `getAuthProviderDescriptors`, `isAuthAvailable`, `signIn`, `signInWithNaver`, `signOut` |
| Health | `isHealthAvailable`, `getHealthSteps` |
| AppsFlyer·딥링크 | `configureAppsFlyer`, `startAppsFlyer`, `setAppsFlyerDeepLinkListener`, `clearAppsFlyerDeepLinkListener`, `configureAppsFlyerJavaScriptBridge`, `clearAppsFlyerJavaScriptBridge`, `handleURL`, `handleUserActivity` |

## 응답과 오류 처리

Completion은 main thread에서 최대 한 번 호출됩니다. 기능 Product가 없거나 초기화되지
않은 경우 앱을 중단시키는 대신 `NSError`, `false`, `nil` 또는 빈 결과로 실패를
전달합니다.

| Completion 형태 | 성공 | 실패 |
| --- | --- | --- |
| `(Bool, NSError?)` | `true`, 일반적으로 `error == nil` | `false`, 가능한 경우 원인 제공 |
| `(String?, NSError?)` | 문자열과 `nil` error | `nil`과 가능한 원인 |
| `([Model]?, NSError?)` | 모델 배열과 `nil` error | `nil`과 가능한 원인 |
| `(Model?, NSError?)` | 모델과 `nil` error | `nil`과 가능한 원인 |

`AppBox.*` Facade 오류 domain은 `kr.co.mobpa.appbox.facade`입니다.

| Code | 오류 | 확인 항목 |
| ---: | --- | --- |
| 1 | `invalidConfiguration` | project ID, URL, provider 값의 누락과 형식 |
| 2 | `moduleUnavailable` | 필요한 Product가 앱 target에 연결됐는지 |
| 3 | `moduleNotConfigured` | 초기화 config에 해당 기능이 포함됐는지 |
| 4 | `conflictingInitialization` | 서로 다른 config로 중복 초기화했는지 |
| 5 | `initializationTimeout` | 모듈 초기화가 제한 시간 안에 끝났는지 |
| 6 | `unsupportedProviderInvocation` | 로그인 함수와 provider 조합이 맞는지 |
| 7 | `underlyingFailure` | 하위 SDK가 반환한 오류 |

Health 오류 domain은 `kr.co.mobpa.appbox.health`이며
`invalidDate`, `invalidRange`, `permissionDenied`, `featureUnavailable`,
`notSupported`, `serviceUnavailable`, `unknown`으로 구분됩니다.

오류를 기록할 때는 `domain`, `code`, `localizedDescription`을 함께 확인하세요.

## 문제 해결과 보안

### 초기화가 실패하는 경우

- `result.core`, `result.webView`, `result.push`, `result.inApp`, `result.auth`,
  `result.health`, `result.appsFlyer`를 각각 확인합니다.
- 앱 target에 필요한 Product가 연결됐는지 확인합니다.
- `projectId`, 서비스 URL과 provider 설정값의 앞뒤 공백과 형식을 확인합니다.
- 디버깅 중에만 `AppBox.setDebugMode(true)`를 사용합니다.

### Push가 동작하지 않는 경우

- Push Notifications Capability와 APNs entitlement를 확인합니다.
- 알림 권한과 APNs 등록 요청을 서로 다른 단계로 처리했는지 확인합니다.
- 원본 APNs `Data`를 `handleAPNSToken`에 전달했는지 확인합니다.
- 앱의 notification delegate가 foreground와 click callback을 한 번씩 전달하는지
  확인합니다.
- silent Push를 사용하면 Background Modes의 Remote notifications를 확인합니다.
- NSE queue를 사용하면 앱과 Extension의 App Group이 같은지 확인합니다.

### WebView bridge가 동작하지 않는 경우

- 초기화한 service URL이 HTTPS이고 host를 포함하는지 확인합니다.
- 고객 WebView를 `attachWebView`로 연결했는지 확인합니다.
- 첫 Web message 전에 native event를 전달한다면 `setActiveWebView`를 호출합니다.
- Navigation 관찰 사용 시 앱이 `navigationDelegate`를 다시 덮어쓰지 않았는지
  확인합니다.

### 보안 주의사항

- project/provider secret, APNs·Firebase token, 사용자 인증 token, 건강 데이터와 전체
  Push payload를 로그·crash report·분석 도구에 남기지 않습니다.
- 운영 저장소에는 placeholder 대신 실제 credential을 직접 작성하지 않습니다.
- ATS 전체 허용을 기본값으로 사용하지 않습니다.
- SDK 함수의 `success`는 해당 요청 처리 결과이며 서버 저장, attribution 또는 알림 도달을
  항상 보장하지 않습니다.

SDK 이용 조건, 기술 지원과 전체 함수 레퍼런스 공개 일정은
[AppBox](https://www.appboxapp.com) 또는 `contact@mobpa.co.kr`로 문의하세요.
