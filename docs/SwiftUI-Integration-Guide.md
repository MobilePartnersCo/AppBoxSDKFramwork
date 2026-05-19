# AppBoxSDK SwiftUI 연동 가이드

SwiftUI `App` lifecycle 앱에서 AppBox 계열 SDK를 연결하는 방법을 정리합니다. UIKit `AppDelegate`/`SceneDelegate` 기반 앱은 README의 기본 통합 가이드를 기준으로 합니다.

## 적용 대상

- `AppBoxSDK` + `AppBoxPushSDK`: AppBox 기본 WebView/bridge 사용
- `AppBoxSDK` + 선택 SDK: Health, SNS Login, AppsFlyer deep link 사용
- `AppBoxPushSDK`: WebView 없이 push-only 사용
- 고객사 자체 `WKWebView`에 `AppBox.shared.attach(webView)`를 붙이는 구성

## 핵심 원칙

AppBoxSDK public API는 UIKit lifecycle을 기준으로 설계되어 있습니다. SwiftUI 앱에서는 아래 adapter로 연결합니다.

- 앱 초기화, APNs token, 원격 알림 callback: `@UIApplicationDelegateAdaptor`
- AppBox 기본 WebView 표시: `UIViewControllerRepresentable`
- 고객사 자체 `WKWebView` 연결: `UIViewRepresentable` 또는 `UIViewControllerRepresentable`
- URL/UserActivity 전달: SwiftUI `.onOpenURL`, `.onContinueUserActivity`

중요한 제약:

- `AppBox.shared.initSDK(...)`는 앱 전체 singleton 상태를 초기화하므로 앱 시작 시 1회만 호출합니다.
- `AppBox.shared.start(from:)`에는 가능한 한 `UINavigationController`를 전달합니다.
- `preloadWebView()`는 key window가 만들어진 뒤 호출합니다.
- SwiftUI multi-window 환경에서는 SDK가 foreground `keyWindow`를 기준으로 동작하므로 단일 window 구성을 권장합니다.

## App lifecycle 연결

아래 예시는 AppBoxSDK + AppBoxPushSDK + SNS Login 선택 조합 기준입니다. SNS Login을 사용하지 않는 앱은 `AppBoxSnsLoginSDK` import와 `AppBoxSnsLogin.shared...` 초기화 코드를 제거합니다.

```swift
import SwiftUI
import UserNotifications
import AppBoxSDK
import AppBoxPushSDK
import AppBoxSnsLoginSDK

@main
struct CustomerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var didPreload = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    guard !didPreload else { return }
                    didPreload = true

                    // key window가 생성된 뒤 호출하는 것을 권장합니다.
                    AppBox.shared.preloadWebView()
                }
                .onOpenURL { url in
                    _ = AppBox.shared.handleURL(url, options: [:])
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    _ = AppBox.shared.handleUserActivity(userActivity)
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Google 로그인 등 Firebase Client ID가 필요한 경우 AppBox init 전에 호출합니다.
        AppBoxPush.shared.initializeFirebaseClientID(
            clientID: "YOUR_FIREBASE_CLIENT_ID"
        )

        AppBox.shared.initSDK(
            baseUrl: "https://example.com",
            projectId: "PROJECT_ID",
            debugMode: true
        )

        AppBox.shared.setPullDownRefresh(used: true)

        // SNS Login을 사용하는 경우 필요한 provider만 초기화합니다.
        AppBoxSnsLogin.shared.initializeKakao(appKey: "YOUR_KAKAO_APP_KEY")
        AppBoxSnsLogin.shared.initializeNaver(
            appName: "YourApp",
            clientId: "YOUR_NAVER_CLIENT_ID",
            clientSecret: "YOUR_NAVER_CLIENT_SECRET",
            urlScheme: "YOUR_NAVER_URL_SCHEME"
        )

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        AppBoxPush.shared.appBoxPushApnsToken(apnsToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        AppBox.shared.handledidReceiveRemoteNotification(userInfo: userInfo)
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        AppBox.shared.movePush(response: response)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.badge, .alert, .sound])
    }
}
```

알림 delegate를 앱에서 이미 사용 중이면 `UNUserNotificationCenter.current().delegate`는 한 객체만 유지됩니다. 기존 delegate가 있다면 해당 delegate에서 AppBox callback을 직접 forward합니다.

## AppBox 기본 WebView 표시

`AppBox.shared.start(from:)`는 `UIViewController`를 인자로 받습니다. SwiftUI에서는 `UIViewControllerRepresentable`로 감쌉니다.

```swift
import SwiftUI
import UIKit
import AppBoxSDK

struct AppBoxManagedWebView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> AppBoxNavigationController {
        AppBoxNavigationController()
    }

    func updateUIViewController(_ uiViewController: AppBoxNavigationController, context: Context) {}
}

final class AppBoxNavigationController: UINavigationController {
    private var didStart = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !didStart else { return }
        didStart = true

        AppBox.shared.start(from: self) { success, error in
            if let error = error {
                print("AppBox start failed: \(error.localizedDescription)")
            }
        }
    }
}
```

SwiftUI 화면에서 표시:

```swift
struct ContentView: View {
    @State private var isAppBoxPresented = false

    var body: some View {
        Button("Open AppBox") {
            isAppBoxPresented = true
        }
        .fullScreenCover(isPresented: $isAppBoxPresented) {
            AppBoxManagedWebView()
                .ignoresSafeArea()
        }
    }
}
```

주의:

- `start(from:)`에 navigation이 없는 단독 `UIViewController`를 넘기면 SDK가 `keyWindow?.rootViewController`를 AppBox navigation으로 교체하는 경로를 탈 수 있습니다.
- SwiftUI 화면 트리를 유지해야 하므로 `UINavigationController` wrapper를 사용합니다.
- `.sheet`보다 `.fullScreenCover`를 권장합니다. SDK 내부 화면은 full screen presentation과 navigation stack을 전제로 동작합니다.
- 같은 wrapper 인스턴스에서 `start(from:)`를 반복 호출하지 않도록 guard를 둡니다.

## 웹뷰 Preload

`preloadWebView()`는 미리 생성한 `WKWebView`를 hidden 상태로 `keyWindow`에 붙여 렌더링을 시작합니다. SwiftUI 앱에서는 앱 시작 직후 key window가 아직 준비되지 않을 수 있으므로 `didFinishLaunching` 안에서 바로 호출하는 것보다 root SwiftUI view의 첫 `.onAppear` 이후 호출하는 것을 권장합니다.

```swift
struct RootView: View {
    @State private var didPreload = false

    var body: some View {
        ContentView()
            .onAppear {
                guard !didPreload else { return }
                didPreload = true
                AppBox.shared.preloadWebView()
            }
    }
}
```

Preload 실패 시에도 `start(from:)`는 정상 경로로 웹뷰를 생성할 수 있습니다. Preload는 하얀 화면을 줄이는 최적화이며 필수 초기화 단계가 아닙니다.

## 고객사 관리 WKWebView 연결

고객사 앱이 직접 소유한 `WKWebView`를 SwiftUI에서 표시하는 경우 `AppBox.shared.attach(webView)`를 사용합니다.

```swift
import SwiftUI
import WebKit
import AppBoxSDK

struct CustomerWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)

        AppBox.shared.attach(webView)
        AppBox.shared.setActiveWebView(webView)

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: ()) {
        AppBox.shared.clearActiveWebView(webView)
        AppBox.shared.detach(webView)
    }
}
```

legacy `appbox` handler까지 필요한 경우에만 다음 API를 사용합니다.

```swift
AppBox.shared.attach(webView, includeLegacyAppboxHandler: true)
```

지원 범위:

| 구분 | action |
| --- | --- |
| 지원 | `appbox.notification.ping`, `appbox.getAppId`, `inapp.*` |
| 미지원 | `message.getToken`, `message.getPushList`, `message.setSegment`, `message.trackConversion`, topic, `storage.*`, `application.*`, `phone.*`, `ui.*`, `scanner.*` |

전체 AppBox bridge action이 필요하면 고객사 관리 `WKWebView` attach가 아니라 AppBox 기본 WebView 방식을 사용합니다.

## Push-only 구성

웹뷰/브릿지 없이 push-only로 사용하는 SwiftUI 앱은 `AppBoxSDK`를 초기화하지 않고 `AppBoxPushSDK`만 초기화합니다.

```swift
import SwiftUI
import UserNotifications
import AppBoxPushSDK

@main
struct PushOnlyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        AppBoxPush.shared.initSDK(
            projectId: "PROJECT_ID",
            debugMode: false,
            autoRegisterForAPNS: true
        ) { result, error, pushPermissionGranted in
            if let error = error {
                print("Push init failed: \(error.localizedDescription)")
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        AppBoxPush.shared.application(
            didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        AppBoxPush.shared.saveNotiClick(response)
        completionHandler()
    }
}
```

권한 요청과 APNs 등록 타이밍을 앱에서 직접 제어해야 하면 `autoRegisterForAPNS: false`로 초기화한 뒤 원하는 시점에 `requestPushAuthorization`과 `UIApplication.shared.registerForRemoteNotifications()`를 호출합니다.

## SNS/URL/UserActivity 처리

SwiftUI `.onOpenURL`에서 AppBox URL 라우팅을 호출합니다.

```swift
.onOpenURL { url in
    _ = AppBox.shared.handleURL(url, options: [:])
}
```

`handleURL(_:options:)`는 다음 순서로 URL을 처리합니다.

1. AppBoxSnsLoginSDK callback
2. AppBoxPushSDK URL handler
3. AppsFlyer URI Scheme deep link

Universal Link/UserActivity는 다음처럼 전달합니다.

```swift
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
    _ = AppBox.shared.handleUserActivity(userActivity)
}
```

주의:

- SwiftUI `.onOpenURL`은 `UIApplication.OpenURLOptionsKey.sourceApplication` 같은 options 정보를 제공하지 않습니다.
- AppsFlyer URI Scheme deep link에서 sourceApplication/annotation 정보 보존이 필요하면 UIKit `SceneDelegate`를 함께 구성해 `AppBox.shared.handleURL(url, options:)`에 options를 전달합니다.
- AppBoxSDK와 AppBoxSnsLoginSDK를 함께 사용하는 경우 URL을 두 SDK에 중복 전달하지 말고 `AppBox.shared.handleURL(...)` 경로만 사용합니다.

## SwiftUI 연동 주의사항

### `start(from:)` 대상

`AppBox.shared.start(from:)`는 전달받은 controller의 navigation stack을 우선 사용합니다. navigation이 없으면 SDK 내부 navigation controller를 만들고 `keyWindow?.rootViewController`를 교체할 수 있습니다.

SwiftUI에서는 `UINavigationController` wrapper를 전달해 SwiftUI root view가 교체되지 않도록 합니다.

### 초기화 반복 호출

`initSDK`는 base URL, project ID, web config, debug 상태, 내부 web manager를 초기화합니다. SwiftUI `body`, `onAppear`, `task`는 여러 번 실행될 수 있으므로 이 위치에서 `initSDK`를 반복 호출하지 않습니다.

권장 위치:

- `UIApplicationDelegate.application(_:didFinishLaunchingWithOptions:)`
- 앱 bootstrap을 담당하는 singleton에서 1회 guard 후 호출

### Notification delegate 충돌

`UNUserNotificationCenter.current().delegate`는 하나만 유지됩니다. 앱에서 자체 notification delegate가 있으면 AppBox callback을 해당 delegate에서 forward합니다.

필수 forward:

- APNs token: `AppBoxPush.shared.appBoxPushApnsToken(apnsToken:)`
- silent push: `AppBox.shared.handledidReceiveRemoteNotification(userInfo:)`
- push click: `AppBox.shared.movePush(response:)`

Push-only 구성:

- APNs token: `AppBoxPush.shared.application(didRegisterForRemoteNotificationsWithDeviceToken:)`
- push click: `AppBoxPush.shared.saveNotiClick(_:)`

### Preload 타이밍

`preloadWebView()`는 `keyWindow` 기준으로 hidden webView를 붙입니다. SwiftUI app launch 직후에는 key window가 없을 수 있으므로 root view가 화면에 올라온 뒤 호출합니다.

### Multi-window

SDK 내부 일부 기능은 foreground `keyWindow` 또는 첫 번째 foreground scene을 기준으로 top view controller를 찾습니다. iPad multi-window, Stage Manager, 여러 `WindowGroup`을 사용하는 앱에서는 AppBox 화면이 의도하지 않은 scene에 표시될 수 있습니다.

권장:

- AppBoxSDK 통합 앱은 단일 `WindowGroup` 기준으로 운영
- AppBox 화면은 현재 사용자 flow에서 명시적으로 띄운 `UINavigationController` wrapper 안에서 실행

### 고객사 관리 WKWebView attach 범위

`attach(webView)`는 고객사 웹뷰의 웹 인앱메시지 lifecycle 연결을 위한 제한된 bridge입니다. 전체 AppBox bridge action이 필요한 웹은 AppBox 기본 WebView를 사용합니다.

### Main thread

화면 표시, URL handling, SNS callback 처리는 main thread에서 호출합니다. SwiftUI modifier에서 호출하는 경우 일반적으로 main thread이지만, 비동기 task에서 호출할 때는 `MainActor`를 사용합니다.

```swift
Task { @MainActor in
    _ = AppBox.shared.handleURL(url, options: [:])
}
```

## 검증 체크리스트

SwiftUI 앱 연동 후 다음 항목을 확인합니다.

- `initSDK`가 앱 실행 중 1회만 호출되는지 확인
- `AppBox.shared.start(from:)`에 `UINavigationController` wrapper가 전달되는지 확인
- AppBox 화면을 열고 닫은 뒤 SwiftUI root 화면이 유지되는지 확인
- `preloadWebView()`가 root view 표시 이후 1회 호출되는지 확인
- APNs token callback이 AppBoxPushSDK로 전달되는지 확인
- foreground/background/silent push callback이 AppBoxSDK 또는 AppBoxPushSDK로 전달되는지 확인
- push 클릭 시 `movePush(response:)` 또는 push-only `saveNotiClick(_:)`가 호출되는지 확인
- SNS 로그인 callback URL이 `.onOpenURL`에서 `AppBox.shared.handleURL(...)`로 전달되는지 확인
- Universal Link를 사용하는 경우 `.onContinueUserActivity`에서 `handleUserActivity`가 호출되는지 확인
- 자체 `WKWebView` attach 사용 시 `dismantleUIView` 또는 화면 종료 시점에 `detach(webView)`가 호출되는지 확인
- iPad/multi-window를 지원하는 앱이라면 AppBox 화면이 의도한 window에 표시되는지 확인
