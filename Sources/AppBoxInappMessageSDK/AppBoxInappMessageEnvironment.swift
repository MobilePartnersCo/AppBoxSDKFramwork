import Foundation
import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

protocol AppBoxInappMessageEnvironmentProviding: AnyObject {
    var apiDomain: String { get }
    var appPackageId: String? { get }

    func currentProjectCode() -> String?
    func currentDeviceUserId() -> String
    func makeApiSecret() -> (apiKey: Data, time: String)?
    @MainActor func currentPresenter() -> UIViewController?
    func log(_ message: String, functionName: String, fileName: String, lineNumber: Int)
}

final class AppBoxInappMessageEnvironment: AppBoxInappMessageEnvironmentProviding {
    static let shared = AppBoxInappMessageEnvironment()

    private let projectIdKey = "appBox_projectId"
    private let deviceUserIdKey = "appBox_pushDui"
    private let sdkBundleIdentifier = "kr.co.mobpa.waveAppSuiteSdk"
    private var apiDomainOverride: String?
    private var presenterProvider: (() -> UIViewController?)?

    private init() {}

    var apiDomain: String {
        if let apiDomainOverride, !apiDomainOverride.isEmpty {
            return apiDomainOverride
        }

        let env = Bundle.main.infoDictionary?["APPBOX_SDK_INTERNAL_SERVER_DEBUG"] as? Bool ?? false
        return env ? "https://apidev.appboxapp.com" : "https://api.appboxapp.com"
    }

    var appPackageId: String? {
        Bundle.main.bundleIdentifier
    }

    func configure(
        projectId: String?,
        apiDomain: String? = nil,
        debugMode: Bool = false,
        deviceUserId: String? = nil,
        presenterProvider: (() -> UIViewController?)? = nil
    ) {
        let trimmedProjectId = projectId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedProjectId.isEmpty {
            UserDefaults.standard.set(trimmedProjectId, forKey: projectIdKey)
        }

        if let apiDomain, !apiDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            apiDomainOverride = apiDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let deviceUserId, !deviceUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.set(deviceUserId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: deviceUserIdKey)
        } else {
            _ = currentDeviceUserId()
        }

        self.presenterProvider = presenterProvider
        CoreConfigStore.shared.isDebug = debugMode
        AppBoxInappMessagePushHandlerRegistry.shared.handler = InappMessageNativeService.shared
    }

    func currentProjectCode() -> String? {
        let projectCode = UserDefaults.standard.string(forKey: projectIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return projectCode?.isEmpty == false ? projectCode : nil
    }

    func currentDeviceUserId() -> String {
        if let value = UserDefaults.standard.string(forKey: deviceUserIdKey),
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }

        let value = Self.randomString(length: 12)
        UserDefaults.standard.set(value, forKey: deviceUserIdKey)
        return value
    }

    func makeApiSecret() -> (apiKey: Data, time: String)? {
        let generated = CoreAES256Cipher().generateKeyAndIV(bundleIdentifier: sdkBundleIdentifier)
        let cipher = CoreAES256Cipher(key: generated.key, iv: generated.iv)
        guard let apiKey = cipher.encrypt(sdkBundleIdentifier) else {
            return nil
        }
        return (apiKey, generated.time)
    }

    @MainActor
    func currentPresenter() -> UIViewController? {
        if let presenter = presenterProvider?() {
            return presenter
        }
        return UIApplication.shared.appBoxInappMessageKeyWindow?.rootViewController?.appBoxInappMessageTopMostViewController
            ?? UIApplication.shared.appBoxInappMessageKeyWindow?.rootViewController
    }

    func log(_ message: String, functionName: String, fileName: String, lineNumber: Int) {
        guard CoreConfigStore.shared.isDebug else { return }
        let fileName = (fileName as NSString).lastPathComponent
        print("[AppBoxInappMessageSDK] [\(fileName):\(lineNumber)] \(functionName) - \(message)")
    }

    private static func randomString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
}

func inappDebugLog(
    _ message: String,
    functionName: String = #function,
    fileName: String = #file,
    lineNumber: Int = #line
) {
    AppBoxInappMessageEnvironment.shared.log(
        message,
        functionName: functionName,
        fileName: fileName,
        lineNumber: lineNumber
    )
}

private extension UIApplication {
    var appBoxInappMessageKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

private extension UIViewController {
    var appBoxInappMessageTopMostViewController: UIViewController {
        if let presented = presentedViewController, !presented.isBeingDismissed {
            return presented.appBoxInappMessageTopMostViewController
        }

        if let navigation = self as? UINavigationController,
           let visible = navigation.visibleViewController {
            return visible.appBoxInappMessageTopMostViewController
        }

        if let tab = self as? UITabBarController,
           let selected = tab.selectedViewController {
            return selected.appBoxInappMessageTopMostViewController
        }

        return self
    }
}
