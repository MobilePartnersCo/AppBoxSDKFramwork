![AppBox_JPG](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSampleiOS/main/resource/image/AppboxVisual.jpg)

# AppBox SDK
[![Swift Package Manager](https://img.shields.io/badge/SPM-Compatible-green.svg)](https://swift.org/package-manager/)
[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/MobilePartnersCo/AppBoxSampleiOS)

- AppBox SDK는 모바일 웹사이트를 앱으로 패키징하여 최소한의 개발로 구글 플레이 및 앱스토어에 등록할 수 있는 솔루션입니다. 
- 앱박스는 모바일 웹사이트에서 자바스크립트 코드를 사용해서 앱의 기능을 사용할 수 있게 하는 솔루션으로 아래 40여가지 기능을 무료로 사용가능합니다.
- SDK 형태로 제공되어 도메인만 입력하면 기본 브라우져 기능부터 간편히 사용 가능합니다.

---

## 라이선스

- 앱박스의 SDK의 사용은 영구적으로 무료입니다. 기업 또는 개인 상업적인 목적으로 사용 할 수 있습니다.

---

## 개발자 메뉴얼

- **메뉴얼**: [https://www.appboxapp.com/guide/dev](https://www.appboxapp.com/guide/dev)

---

## 데모앱 다운로드

- GooglePlay : https://play.google.com/store/apps/details?id=kr.co.mobpa.appbox
- AppStore : https://apps.apple.com/kr/app/id6737824370

---

## 전체 기능

- 브라우저의 기본기능 
- 생체 인증, 탭 메뉴, 브라우저 메뉴, 햄버거 메뉴, 진동 울리기, 로딩 아이콘, 토스트 메시지, 인트로 실행하기 
- 플로팅 메뉴, 로컬 푸시, 앱 평가, 달력 실행, 팝업 실행하기, 이미지 뷰어, 외부 페이지 열기
- 바코드 리더기 실행하기, QR 팝업 실행하기, 바코드 팝업 실행하기, 업데이트 실행, 다른 앱 실행하기
- QR 리더기 실행하기, 공유하기, 앱 종료, 위치를 받아옴, 전화걸기, 문자보내기, 걸음수, 푸시 토큰 등록, API 실행하기 등

---

## 브라우저의 기본기능

- 앞/뒤로 이동: 사용자가 이전 페이지로 돌아가거나 앞으로 이동 가능.
- 새로 고침: 현재 페이지를 다시 로드.
- 홈 버튼: 설정된 기본 URL로 빠르게 이동.
- 페이지 공유: 현재 URL을 다른 앱(메시지, 이메일 등)으로 공유.
- 에러 처리: 인터넷 연결 문제나 페이지 로딩 오류 시 사용자에게 메시지 표시.
- 풀스크린 지원: 웹사이트의 풀스크린 콘텐츠(동영상 등) 표시.
- 파일 업/다운로드: WebView 내에서 파일 업로드 및 다운로드 지원.
- window.open()으로 새창 열기

---

## 설치 방법

AppBoxSDK는 [Swift Package Manager](https://swift.org/package-manager/)를 통해 배포됩니다. SPM 설치를 위해 다음 단계를 따라주세요:

1. Xcode에서 ①[Project Target] > ②[Package Dependencies] > ③[Packages +]를 눌러 패키지 추가 화면을 엽니다.
![SPM_Step1_Image](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSampleiOS/main/resource/image/spm1.png)

3. 다음 SPM URL 복사합니다:
   ```console
   https://github.com/MobilePartnersCo/AppBoxSDKFramwork
   ```

4. ④[검색창] SPM URL 검색 > ⑤[Dependency Rule] `Up to Next Major Version 최신 버전` 입력 > ⑥[Add Package]를 눌러 패키지 추가합니다.
![SPM_Step3_Image](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSampleiOS/main/resource/image/spm2.png)

5. 설정 완료
![SPM_Step4_Image](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSampleiOS/main/resource/image/spm3.png)


### Info.plist 설정

SDK를 사용하려면 `Info.plist` 파일에 아래와 같은 항목을 추가하세요:

```xml
<key>NSFaceIDUsageDescription</key>
<string>생체인증을 사용하기 위해 필요합니다.</string>
<key>NSCameraUsageDescription</key>
<string>카메라를 사용하기 위해 필요합니다.</string>
<key>NSHealthShareUsageDescription</key>
<string>걸음수를 가져오기 위해 필요합니다.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>걸음수를 가져오기 위해 필요합니다.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>위치정보 제공을 위해 필요합니다.</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Signing & Capabilities 설정

걸음수를 사용하려면 `Signing & Capabilities`에 HealthKit을 추가해야합니다. 다음 단계를 따라주세요:

1. Xcode에서 ①[Targets Target] > ②[Signing & Capabilities] > ③[+ Capability]를 눌러 Capability 추가 화면을 엽니다.
![Signing_Step1_Image](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSampleiOS/main/resource/image/signing1.png)

2. Xcode에서 ④[검색창]에 `HealthKit` 입력  > ⑤더블클릭하여 적용합니다.
![Signing_Step2_Image](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSampleiOS/main/resource/image/signing2.png)

3. 설정 완료
![Signing_Step3_Image](https://raw.githubusercontent.com/MobilePartnersCo/AppBoxSampleiOS/main/resource/image/signing3.png)

---

## 사용법

### 1. SDK 초기화

AppBox SDK를 사용하려면 먼저 초기화를 수행해야 합니다. initSDK 메서드를 호출하여 초기화를 완료하세요.

`AppDelegate`에서 초기화를 진행합니다.

#### import 설정:

```swift
import AppBoxSDK
import WebKit
```

#### 예제 코드:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
// AppBox WebConfig 설정
let appBoxWebConfig = AppBoxWebConfig()
let wkWebViewConfig = WKWebViewConfiguration()
if #available(iOS 14.0, *) {
   wkWebViewConfig.defaultWebpagePreferences.allowsContentJavaScript = true
} else {
   wkWebViewConfig.preferences.javaScriptEnabled = true
}
appBoxWebConfig.wKWebViewConfiguration = wkWebViewConfig

// AppBox 초기화
AppBox.shared.initSDK(
   baseUrl: "https://www.example.com",
   webConfig: appBoxWebConfig,
   debugMode: true
)

return true
}
```

---

### 2. SDK 실행

초기화된 SDK를 실행하려면 start 메서드를 호출하세요. 실행 결과는 콜백을 통해 전달됩니다.

#### 예제 코드:

```swift

// AppBox 실행
AppBox.shared.start(from: self) { isSuccess, error in
   if isSuccess {
       // 실행 성공 처리
       print("AppBox:: SDK 실행 성공")
   } else {
       // 실행 실패 처리
       if let error = error {
           print("error : \(error.localizedDescription)")
       } else {
           print("error : unkown Error")
       }
   }
}
```

---

### 3. 추가 기능 설정

AppBox SDK 실행 전 추가 기능이 설정이 되어야 적용이 됩니다.

- #### **푸시 토큰 설정**

APNS에서 발급 받은 푸시 토큰 또는 FCM 푸시 토큰을 저장합니다.

#### 예제 코드:

```swift
// AppBox 푸시 토큰 설정
AppBox.shared.setPushToken("푸시 토큰 값")
```

- #### **로컬 푸시 설정**

로컬 푸시를 받기 위해 `Appdelegate`에 다음과 같이 설정합니다.

#### 예제 코드:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
// AppBox 로컬 푸시 설정
let center = UNUserNotificationCenter.current()
center.delegate = self

return true
}
```

```swift
// AppBox 로컬 푸시 설정
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}
```

- #### **인트로 설정**

최초 앱 설치 후 AppBox SDK를 실행 시 인트로 화면이 노출됩니다.

#### 예제 코드:

```swift
// AppBox 인트로 설정
if let appBoxIntroItem1 = AppBoxIntro(imageUrl: "https://www.example.com/example1.png"),
  let appBoxIntroItem2 = AppBoxIntro(imageUrl: "https://www.example.com/example2.png") {
   let items = [
       appBoxIntroItem1,
       appBoxIntroItem2
   ]
   AppBox.shared.setIntro(items)
}
```

- #### **당겨서 새로고침 설정**

스크롤을 당기면 웹이 새로고침되는 기능입니다.

사용여부 설정에 따라서 당겨서 새로고침 기능이 적용이 됩니다.

#### 예제 코드:

```swift
// AppBox 당겨서 새로고침 설정
AppBox.shared.setPullDownRefresh(
   used: true
)
```

---

## 요구 사항

- **iOS** 13.0 이상
- **Swift** 5.1 이상
- **Xcode** 14.0 이상

---

## 주의 사항

1. **초기화 필수**
   - initSDK를 호출하여 SDK를 초기화한 후에만 다른 기능을 사용할 수 있습니다.
   - 초기화를 수행하지 않으면 실행 시 예외가 발생할 수 있습니다.

---

## 지원

문제가 발생하거나 추가 지원이 필요한 경우 아래로 연락하세요:

- **이메일**: [contact@mobpa.co.kr](mailto:contact@mobpa.co.kr)
- **홈페이지**: [https://www.appboxapp.com](https://www.appboxapp.com)

---
