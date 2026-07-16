import Foundation
import UIKit
import WebKit
import AppBoxCoreSDK

extension AppBoxSnsLogin: AppBoxAuthFacadeRuntimeProviding {
    public static var appBoxAuthFacadeRuntime: AppBoxAuthFacadeRuntime {
        AppBoxAuthFacadeRuntimeAdapter.shared
    }
}

private final class AppBoxAuthFacadeRuntimeAdapter: AppBoxAuthFacadeRuntime {
    static let shared = AppBoxAuthFacadeRuntimeAdapter()

    private let repository = AppBoxSnsLoginRepository.shared
    private let lock = NSLock()
    private var configured: [Int: Bool] = [0: false, 1: false, 2: false, 3: false]

    private init() {}

    func configure(
        googleEnabled: Bool,
        appleEnabled: Bool,
        kakaoNativeAppKey: String?,
        naverAppName: String?,
        naverClientId: String?,
        naverClientSecret: String?,
        naverURLScheme: String?,
        completion: @escaping ([String: NSError]) -> Void
    ) {
        if let kakaoNativeAppKey, !kakaoNativeAppKey.isEmpty {
            repository.initializeKakao(appKey: kakaoNativeAppKey)
        }

        let hasNaver = [naverAppName, naverClientId, naverClientSecret, naverURLScheme]
            .allSatisfy { $0?.isEmpty == false }
        if hasNaver,
           let naverAppName,
           let naverClientId,
           let naverClientSecret,
           let naverURLScheme {
            repository.initializeNaver(
                appName: naverAppName,
                clientId: naverClientId,
                clientSecret: naverClientSecret,
                urlScheme: naverURLScheme
            )
        }

        lock.lock()
        configured = [
            0: googleEnabled,
            1: appleEnabled,
            2: kakaoNativeAppKey?.isEmpty == false,
            3: hasNaver
        ]
        lock.unlock()
        DispatchQueue.main.async { completion([:]) }
    }

    func configuredProviders() -> [Int: Bool] {
        lock.lock()
        defer { lock.unlock() }
        return configured
    }

    func signIn(
        provider: Int,
        presentingViewController: AnyObject,
        completion: @escaping ([String: Any]?, NSError?) -> Void
    ) {
        guard let viewController = presentingViewController as? UIViewController else {
            completion(nil, error("presentingViewController must be UIViewController"))
            return
        }

        let callback: (Bool, [String: Any]?, Error?) -> Void = { success, data, underlyingError in
            completion(success ? data : nil, underlyingError.map { $0 as NSError } ?? (success ? nil : self.error("sign in failed")))
        }

        switch provider {
        case 0:
            repository.signInWithGoogle(presentingViewController: viewController, completion: callback)
        case 1:
            repository.signInWithApple(presentingViewController: viewController, completion: callback)
        case 2:
            repository.signInWithKakao(presentingViewController: viewController, completion: callback)
        default:
            completion(nil, error("unsupported provider"))
        }
    }

    func signInWithNaver(
        webView: AnyObject,
        callId: String?,
        completion: @escaping ([String: Any]?, NSError?) -> Void
    ) {
        guard let webView = webView as? WKWebView else {
            completion(nil, error("webView must be WKWebView"))
            return
        }

        repository.signInWithNaver(webView: webView, callId: callId) { success, data, underlyingError in
            completion(success ? data : nil, underlyingError.map { $0 as NSError } ?? (success ? nil : self.error("Naver sign in failed")))
        }
    }

    func signOut(provider: Int, completion: @escaping (Bool, NSError?) -> Void) {
        let callback: (Bool, Error?) -> Void = { success, underlyingError in
            completion(success, underlyingError.map { $0 as NSError })
        }
        switch provider {
        case 0: repository.signOutWithGoogle(completion: callback)
        case 1: repository.signOutWithApple(completion: callback)
        case 2: repository.signOutWithKakao(completion: callback)
        case 3: repository.signOutWithNaver(completion: callback)
        default: completion(false, error("unsupported provider"))
        }
    }

    @MainActor func canHandleURL(_ url: URL) -> Bool {
        repository.canHandleURL(url)
    }

    @MainActor func handleURL(_ url: URL) -> Bool {
        repository.handleURL(url)
    }

    private func error(_ message: String) -> NSError {
        NSError(
            domain: "kr.co.mobpa.appbox.auth",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
