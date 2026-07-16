import Foundation
import UserNotifications
import AppBoxCoreSDK

extension AppBoxPush: AppBoxPushFacadeRuntimeProviding {
    public static var appBoxPushFacadeRuntime: AppBoxPushFacadeRuntime {
        AppBoxPushFacadeRuntimeAdapter.shared
    }
}

protocol AppBoxPushLifecycleRepository: AnyObject {
    func appBoxPushApnsToken(apnsToken: Data)
    func recordNotificationReceived(_ request: UNNotificationRequest)
    func importReceivedNotifications()
    func recordPushDelivered(_ request: UNNotificationRequest)
    func recordPushDelivered(userInfo: NSDictionary)
    func sendJourneyPushReceived(
        request: UNNotificationRequest,
        state: String,
        completion: ((Bool) -> Void)?
    )
}

extension AppBoxPushRepository: AppBoxPushLifecycleRepository {}

final class AppBoxPushFacadeRuntimeAdapter: AppBoxPushFacadeRuntime, AppBoxPushLifecycleFacadeRuntime {
    static let shared = AppBoxPushFacadeRuntimeAdapter()

    private let repository = AppBoxPushRepository.shared
    private let lifecycleRepository: AppBoxPushLifecycleRepository

    init(lifecycleRepository: AppBoxPushLifecycleRepository = AppBoxPushRepository.shared) {
        self.lifecycleRepository = lifecycleRepository
    }

    func configureCoreProvider(_ provider: AnyObject?) {
        AppBoxPush.configureCoreProviderObject(provider)
    }

    func initialize(
        projectId: String,
        debugMode: Bool,
        firebaseClientID: String?,
        completion: @escaping (Bool, NSError?) -> Void
    ) {
        if let firebaseClientID, !firebaseClientID.isEmpty {
            repository.initializeFirebaseClientID(clientID: firebaseClientID)
        }

        repository.initSDK(
            projectId: projectId,
            debugMode: debugMode,
            autoRegisterForAPNS: false
        ) { _, error, _ in
            completion(error == nil, error)
        }
    }

    func getPushToken() -> String? {
        repository.getPushToken()
    }

    func requestPushAuthorization(completion: @escaping (Bool, NSError?) -> Void) {
        repository.requestPushAuthorization { granted in
            completion(granted, nil)
        }
    }

    func savePushToken(
        _ token: String,
        pushEnabled: Bool,
        completion: @escaping (Bool, NSError?) -> Void
    ) {
        repository.savePushToken(token: token, pushYn: pushEnabled) { result, error in
            completion(result != nil && error == nil, error)
        }
    }

    func savePushSegment(
        _ segment: [String: String],
        completion: @escaping (Bool, NSError?) -> Void
    ) {
        repository.saveSegment(segment: segment) { result, error in
            completion(result != nil && error == nil, error)
        }
    }

    func subscribeToTopic(_ topic: String, completion: @escaping (Bool, NSError?) -> Void) {
        repository.subscribeToTopic(topic, completion: completion)
    }

    func unsubscribeFromTopic(_ topic: String, completion: @escaping (Bool, NSError?) -> Void) {
        repository.unsubscribeFromTopic(topic, completion: completion)
    }

    func trackConversion(_ conversionCode: String, completion: @escaping (Bool, NSError?) -> Void) {
        repository.trackingConversion(conversionCode: conversionCode, completion: completion)
    }

    @MainActor func handleURL(_ url: URL) -> Bool {
        // 현재 Push SDK에는 URL callback 계약이 없습니다. typed chain의 순서만 보존합니다.
        false
    }

    @MainActor func handleAPNSToken(_ deviceToken: Data) {
        lifecycleRepository.appBoxPushApnsToken(apnsToken: deviceToken)
    }

    @MainActor func recordRemoteNotification(userInfo: NSDictionary) {
        lifecycleRepository.recordPushDelivered(userInfo: userInfo)
    }

    @MainActor func handleForegroundNotification(_ request: UNNotificationRequest) {
        lifecycleRepository.recordNotificationReceived(request)
        lifecycleRepository.importReceivedNotifications()
        lifecycleRepository.recordPushDelivered(request)
        lifecycleRepository.sendJourneyPushReceived(request: request, state: "FG", completion: nil)
    }
}
