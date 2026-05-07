//
//  PushOnlyAppBoxPushCoreProvider.swift
//  AppBoxPushSDK
//

import Foundation
import UserNotifications
@_spi(AppBoxInternal) @_spi(AppBoxPushSDK) import AppBoxCoreSDK

final class PushOnlyAppBoxPushCoreProvider: AppBoxPushCoreProviding {
    static let shared = PushOnlyAppBoxPushCoreProvider()

    private let corePushApi = CorePushApi()
    private let coreSegApi = CoreSegApi()
    private let coreConversionApi = CoreConversionApi()
    private let projectIdKey = "appBox_projectId"
    private let pushTokenKey = "appBox_pushToken"
    private let pushYnKey = "appBox_pushYn"
    private let deviceUserIdKey = "appBox_pushDui"

    private init() {}

    func configure(projectId: String, debugMode: Bool) {
        UserDefaults.standard.set(projectId, forKey: projectIdKey)
        CoreConfigStore.shared.isDebug = debugMode
        _ = getOrCreateDeviceUserId()
    }

    func getProjectId() -> String? {
        UserDefaults.standard.string(forKey: projectIdKey)
    }

    func getPushInfo(_ projectId: String, completion: @escaping (Bool, AppBoxPushFirebaseInfo?) -> Void) {
        guard let appPackageId = Bundle.main.bundleIdentifier else {
            completion(false, nil)
            return
        }

        let secret = makeApiKey()
        guard let apiKey = secret.apiKey else {
            completion(false, nil)
            return
        }

        corePushApi.getPushInfo(
            apiDomain: apiDomain,
            apiKey: apiKey,
            time: secret.time,
            projectId: projectId,
            appPackageId: appPackageId
        ) { result in
            switch result {
            case .success(let model):
                guard model.success, let data = model.data else {
                    completion(false, nil)
                    return
                }
                completion(true, AppBoxPushFirebaseInfo(
                    project_id: data.project_id,
                    app_id: data.app_id,
                    api_key: data.api_key,
                    sender_id: data.sender_id
                ))
            case .failure:
                completion(false, nil)
            }
        }
    }

    func getPushToken() -> String? {
        UserDefaults.standard.string(forKey: pushTokenKey)
    }

    func setPushToken(_ token: String, pushYn: String, completion: ((Bool) -> Void)?) {
        guard let projectId = getProjectId(),
              !projectId.isEmpty,
              let appPackageId = Bundle.main.bundleIdentifier else {
            completion?(false)
            return
        }

        let secret = makeApiKey()
        guard let apiKey = secret.apiKey else {
            completion?(false)
            return
        }

        corePushApi.setPushToken(
            apiDomain: apiDomain,
            apiKey: apiKey,
            time: secret.time,
            projectId: projectId,
            deviceUserId: getOrCreateDeviceUserId(),
            appPackageId: appPackageId,
            token: token,
            pushYn: pushYn
        ) { result in
            switch result {
            case .success(let model):
                if model.success {
                    UserDefaults.standard.set(token, forKey: self.pushTokenKey)
                    if pushYn == "Y" || pushYn == "N" {
                        UserDefaults.standard.set(pushYn, forKey: self.pushYnKey)
                    }
                }
                completion?(model.success)
            case .failure:
                completion?(false)
            }
        }
    }

    func setFCMImage(_ request: UNNotificationRequest, contentHandler: @escaping ((UNNotificationContent) -> Void)) {
        contentHandler(request.content)
    }

    func setSegment(_ segment: [String: String], completion: @escaping (Bool) -> Void) {
        saveSegment(segment) { success, _ in
            completion(success)
        }
    }

    func saveSegment(_ segment: [String: String], completion: @escaping (Bool, NSError?) -> Void) {
        guard let projectId = getProjectId(),
              !projectId.isEmpty else {
            completion(false, providerError(code: -1001, message: "projectId is empty"))
            return
        }

        let secret = makeApiKey()
        guard let apiKey = secret.apiKey else {
            completion(false, providerError(code: -1009, message: "api key generation failed"))
            return
        }

        coreSegApi.setSeg(
            apiDomain: apiDomain,
            apiKey: apiKey,
            time: secret.time,
            projectId: projectId,
            deviceUserId: getOrCreateDeviceUserId(),
            data: segment
        ) { result in
            switch result {
            case .success(let model):
                if model.success {
                    completion(true, nil)
                } else {
                    completion(false, self.providerError(code: model.code, message: "\(model.message)(\(model.code))"))
                }
            case .failure(let error):
                completion(false, error as NSError)
            }
        }
    }

    func trackConversion(conversionCode: String, completion: @escaping (Bool, NSError?) -> Void) {
        let trimmed = conversionCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(false, providerError(code: -1009, message: "conversionCode is empty"))
            return
        }

        guard let projectId = getProjectId(),
              !projectId.isEmpty else {
            completion(false, providerError(code: -1001, message: "projectId is empty"))
            return
        }

        guard let meta = ConversionMetadataStore.shared.read(for: trimmed),
              let campaignCode = meta.campaignCode else {
            completion(false, providerError(code: -1015, message: "conversion metadata not found"))
            return
        }

        let secret = makeApiKey()
        guard let apiKey = secret.apiKey else {
            completion(false, providerError(code: -1009, message: "api key generation failed"))
            return
        }

        coreConversionApi.sendConversion(
            apiDomain: apiDomain,
            apiKey: apiKey,
            time: secret.time,
            projectId: projectId,
            conversionCode: trimmed,
            campaignCode: campaignCode,
            pushIdx: meta.pushIdx
        ) { result in
            switch result {
            case .success(let model):
                if model.success {
                    ConversionMetadataStore.shared.remove(for: trimmed)
                    completion(true, nil)
                } else {
                    completion(false, self.providerError(code: model.code, message: model.message))
                }
            case .failure(let error):
                completion(false, error as NSError)
            }
        }
    }

    func fetchSubscribableTopics(eventType: String, topics: [String], completion: @escaping (Bool, [String], NSError?) -> Void) {
        guard let projectId = getProjectId(),
              !projectId.isEmpty else {
            completion(false, [], providerError(code: -1001, message: "projectId is empty"))
            return
        }

        let secret = makeApiKey()
        guard let apiKey = secret.apiKey else {
            completion(false, [], providerError(code: -1009, message: "api key generation failed"))
            return
        }

        corePushApi.fetchTopicFilter(
            apiDomain: apiDomain,
            apiKey: apiKey,
            time: secret.time,
            projectId: projectId,
            deviceUserId: getOrCreateDeviceUserId(),
            eventType: eventType,
            topics: topics
        ) { result in
            switch result {
            case .success(let model):
                if model.success {
                    completion(true, model.data?.subscribable ?? [], nil)
                } else {
                    completion(false, [], self.providerError(code: model.code, message: "\(model.message)(\(model.code))"))
                }
            case .failure(let error):
                completion(false, [], error as NSError)
            }
        }
    }

    func sendPushTopicCallback(eventType: String, topic: String, completion: ((Bool) -> Void)?) {
        sendPushTopicCallback(eventType: eventType, topics: [topic]) { success, _ in
            completion?(success)
        }
    }

    func sendPushTopicCallback(eventType: String, topics: [String], completion: @escaping (Bool, NSError?) -> Void) {
        guard let projectId = getProjectId(),
              !projectId.isEmpty else {
            completion(false, providerError(code: -1001, message: "projectId is empty"))
            return
        }

        let secret = makeApiKey()
        guard let apiKey = secret.apiKey else {
            completion(false, providerError(code: -1009, message: "api key generation failed"))
            return
        }

        corePushApi.sendTopicCallback(
            apiDomain: apiDomain,
            apiKey: apiKey,
            time: secret.time,
            projectId: projectId,
            deviceUserId: getOrCreateDeviceUserId(),
            eventType: eventType,
            topics: topics
        ) { result in
            switch result {
            case .success(let model):
                if model.success {
                    completion(true, nil)
                } else {
                    completion(false, self.providerError(code: model.code, message: "\(model.message)(\(model.code))"))
                }
            case .failure(let error):
                completion(false, error as NSError)
            }
        }
    }

    func savePushClick(userInfo: [AnyHashable: Any], completion: ((Bool) -> Void)?) {
        guard let projectId = getProjectId(),
              !projectId.isEmpty,
              let pushIdx = Self.payloadString(userInfo["idx"]),
              let appPackageId = Bundle.main.bundleIdentifier else {
            completion?(false)
            return
        }

        let secret = makeApiKey()
        guard let apiKey = secret.apiKey else {
            completion?(false)
            return
        }

        corePushApi.setPushClick(
            apiDomain: apiDomain,
            apiKey: apiKey,
            time: secret.time,
            projectId: projectId,
            pushIdx: pushIdx,
            appPackageId: appPackageId
        ) { result in
            switch result {
            case .success(let model):
                completion?(model.success)
            case .failure:
                completion?(false)
            }
        }
    }

    private var apiDomain: String {
        let env = Bundle.main.infoDictionary?["APPBOX_SDK_INTERNAL_SERVER_DEBUG"] as? Bool ?? false
        return env ? "https://apidev.appboxapp.com" : "https://api.appboxapp.com"
    }

    private func makeApiKey() -> (apiKey: Data?, time: String) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let generated = CoreAES256Cipher().generateKeyAndIV(bundleIdentifier: bundleIdentifier)
        let cipher = CoreAES256Cipher(key: generated.key, iv: generated.iv)
        return (cipher.encrypt(bundleIdentifier), generated.time)
    }

    private func providerError(code: Int, message: String) -> NSError {
        NSError(domain: "AppBoxPushSDK", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func getOrCreateDeviceUserId() -> String {
        if let value = UserDefaults.standard.string(forKey: deviceUserIdKey), !value.isEmpty {
            return value
        }

        let value = Self.randomString(length: 12)
        UserDefaults.standard.set(value, forKey: deviceUserIdKey)
        return value
    }

    private static func randomString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private static func payloadString(_ value: Any?) -> String? {
        let rawValue: String?
        switch value {
        case let string as String:
            rawValue = string
        case let number as NSNumber:
            rawValue = number.stringValue
        default:
            rawValue = nil
        }

        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}
