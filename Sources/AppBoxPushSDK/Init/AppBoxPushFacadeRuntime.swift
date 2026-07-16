import Foundation
import AppBoxCoreSDK

extension AppBoxPush: AppBoxPushFacadeRuntimeProviding {
    public static var appBoxPushFacadeRuntime: AppBoxPushFacadeRuntime {
        AppBoxPushFacadeRuntimeAdapter.shared
    }
}

private final class AppBoxPushFacadeRuntimeAdapter: AppBoxPushFacadeRuntime {
    static let shared = AppBoxPushFacadeRuntimeAdapter()

    private let repository = AppBoxPushRepository.shared

    private init() {}

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
}
