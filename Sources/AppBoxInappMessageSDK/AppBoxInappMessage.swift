import Foundation
import UIKit
@_spi(AppBoxInternal) import AppBoxWatermarkSupport

/// 인앱 메시지에서 발생한 액션 한 건.
///
/// `AppBoxSDK`의 `@objc` 타입 `AppBoxInAppActionEvent`로 그대로 옮겨진다. 그 타입을 여기서 직접
/// 쓸 수 없는 이유는 의존 방향이 반대이기 때문이다(`AppBoxSDK` → `AppBoxInappMessageSDK`).
public struct AppBoxInappMessageActionInfo {
    /// 액션이 발생한 캠페인 코드.
    public let campaignCode: String
    /// 액션 종류.
    ///
    /// SDK가 처리하는 값은 `"close"` `"link"` `"dismiss-today"` `"function"` `"external"`
    /// `"event"` `"conversion"` 이다. `"none"`은 통지하지 않으므로 여기 담기지 않는다.
    ///
    /// **서버 콘솔이 실제로 생성하는 값은 더 좁다.** 버튼은 `close` `link` `dismiss-today`
    /// `function`, 이미지는 `none` `link` `close` `function` 뿐이다(서버팀 확인, 2026-07-28).
    public let action: String
    /// 비어 있을 수 있다. X 버튼과 딤 탭은 항상 빈 문자열이다.
    public let actionValue: String

    public init(campaignCode: String, action: String, actionValue: String) {
        self.campaignCode = campaignCode
        self.action = action
        self.actionValue = actionValue
    }
}

public typealias AppBoxInappMessageActionListener = (AppBoxInappMessageActionInfo) -> Void

protocol InappMessageNativeServing: AnyObject {
    func bootstrap()
    func handleDidBecomeActive()
    func handleDidEnterBackground()
    func sync(completion: ((Bool, Error?) -> Void)?)
    func enterDisplayScreen(delay: TimeInterval)
    func leaveDisplayScreen()
    func show(
        campaignCode: String,
        instanceId: String?,
        journeyId: Int?,
        nodeCode: String?,
        completion: ((InappMessageNativeServiceResult) -> Void)?
    )
    func setActionListener(_ listener: AppBoxInappMessageActionListener?)
}

@objc(AppBoxInappMessageSDK)
public final class AppBoxInappMessage: NSObject {
    @objc public static let shared = AppBoxInappMessage()

    private let service: InappMessageNativeServing
    private let configureEnvironment: Bool
    private let registerWatermark: (String?) -> Void
    private var lifecycleObservers = [NSObjectProtocol]()

    init(
        service: InappMessageNativeServing = InappMessageNativeService.shared,
        configureEnvironment: Bool = true,
        registerWatermark: @escaping (String?) -> Void = { projectId in
            AppBoxWatermarkManager.shared.register(
                owner: .inappMessage,
                projectId: projectId,
                contextProvider: AppBoxInappMessageEnvironment.shared
            )
        }
    ) {
        self.service = service
        self.configureEnvironment = configureEnvironment
        self.registerWatermark = registerWatermark
        super.init()
    }

    deinit {
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
    }

    @objc(configureWithProjectId:debugMode:)
    public static func configure(projectId: String?, debugMode: Bool) {
        AppBoxInappMessageEnvironment.shared.configure(projectId: projectId, debugMode: debugMode)
    }

    public static func configure(
        projectId: String?,
        apiDomain: String? = nil,
        debugMode: Bool = false,
        deviceUserId: String? = nil,
        presenterProvider: (() -> UIViewController?)? = nil
    ) {
        AppBoxInappMessageEnvironment.shared.configure(
            projectId: projectId,
            apiDomain: apiDomain,
            debugMode: debugMode,
            deviceUserId: deviceUserId,
            presenterProvider: presenterProvider
        )
    }

    @objc(initSDKWithProjectId:)
    public func initSDK(projectId: String?) {
        initSDK(projectId: projectId, debugMode: false)
    }

    @objc(initSDKWithProjectId:debugMode:)
    public func initSDK(projectId: String?, debugMode: Bool) {
        initSDK(projectId: projectId, apiDomain: nil, debugMode: debugMode, deviceUserId: nil, presenterProvider: nil)
    }

    public func initSDK(
        projectId: String?,
        apiDomain: String? = nil,
        debugMode: Bool = false,
        deviceUserId: String? = nil,
        presenterProvider: (() -> UIViewController?)? = nil
    ) {
        if configureEnvironment {
            Self.configure(
                projectId: projectId,
                apiDomain: apiDomain,
                debugMode: debugMode,
                deviceUserId: deviceUserId,
                presenterProvider: presenterProvider
            )
        }
        registerWatermark(projectId)
        service.bootstrap()
        startObservingLifecycleIfNeeded()
    }

    @objc public func sync() {
        service.sync(completion: nil)
    }

    @objc(syncWithCompletion:)
    public func sync(completion: ((Bool, NSError?) -> Void)?) {
        service.sync { success, error in
            completion?(success, error as NSError?)
        }
    }

    @objc public func enterDisplayScreen() {
        service.enterDisplayScreen(delay: 0)
    }

    @objc(enterDisplayScreenWithDelay:)
    public func enterDisplayScreen(delay: TimeInterval) {
        service.enterDisplayScreen(delay: delay)
    }

    @objc public func leaveDisplayScreen() {
        service.leaveDisplayScreen()
    }

    @objc(showCampaignCode:)
    public func show(campaignCode: String) {
        service.show(campaignCode: campaignCode, instanceId: nil, journeyId: nil, nodeCode: nil, completion: nil)
    }

    @objc(showCampaignCode:completion:)
    public func show(campaignCode: String, completion: ((Bool, NSError?) -> Void)?) {
        service.show(campaignCode: campaignCode, instanceId: nil, journeyId: nil, nodeCode: nil) { result in
            switch result {
            case .shown, .queued:
                completion?(true, nil)
            case .skipped(let reason):
                completion?(false, NSError(domain: "AppBoxInappMessage", code: 0, userInfo: [NSLocalizedDescriptionKey: reason]))
            case .failed(let message):
                completion?(false, NSError(domain: "AppBoxInappMessage", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
            }
        }
    }

    public func setActionListener(_ listener: AppBoxInappMessageActionListener?) {
        service.setActionListener(listener)
    }

    private func startObservingLifecycleIfNeeded() {
        guard lifecycleObservers.isEmpty else { return }

        let center = NotificationCenter.default
        lifecycleObservers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.service.handleDidBecomeActive()
        })

        lifecycleObservers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.service.handleDidEnterBackground()
        })
    }
}
