//
//  AppBoxPushRepository.swift
//  appboxpush
//
//  Created by mobilePartners on 1/24/25.
//


import UIKit
import UserNotifications
@_spi(AppBoxInternal) @_spi(AppBoxPushSDK) import AppBoxCoreSDK
import Firebase

class AppBoxPushRepository: NSObject, AppBoxPushProtocol {

    static let shared = AppBoxPushRepository()
    weak var delegate: AppBoxPushDelegate?
    let center = UNUserNotificationCenter.current()

    typealias InitSDKCompletion = (AppBoxNotiResultModel?, NSError?, NSNumber?) -> Void
    typealias PushTokenCompletion = (AppBoxNotiResultModel?, NSError?) -> Void

    // 초기화 중복 호출 방지 플래그
    private var isInitializing = false

    // Firebase Client ID 저장
    private static var firebaseClientID: String?
    private let pushOnlyCoreProvider = PushOnlyAppBoxPushCoreProvider.shared
    private var processedPushClickIds = Set<String>()
    private let processedPushClickIdsLock = NSLock()

    // MARK: - UserDefaults Keys (AppBoxPushSDK 전용)
    private let kLastAppliedPushYn = "appBox_lastAppliedPushYn" // legacy: 마지막으로 고정 토픽에 적용한 pushYN 값
    private let kFixedTopicSignature = "appBox_fixedTopicSignature"
    private let fixedTopicSignatureVersion = "v2"
    private let topicRegex = "^[a-zA-Z0-9_-]+$"
    private let maxTopicLength = 200

    /// 마지막으로 고정 토픽에 적용한 pushYN ("Y"/"N"/nil)
    private var lastAppliedPushYn: String? {
        get { UserDefaults.standard.string(forKey: kLastAppliedPushYn) }
        set { UserDefaults.standard.set(newValue, forKey: kLastAppliedPushYn) }
    }

    /// 마지막으로 성공 적용한 고정 토픽 규칙 signature.
    /// 단순 "처리 완료" 플래그가 아니라 현재 SDK가 요구하는 토픽 목록을 저장해
    /// 토픽 규칙 변경 시 기존 설치 사용자도 자동으로 재동기화되도록 한다.
    private var fixedTopicSignature: String? {
        get { UserDefaults.standard.string(forKey: kFixedTopicSignature) }
        set { UserDefaults.standard.set(newValue, forKey: kFixedTopicSignature) }
    }

    /// 고정 토픽 목록 (규칙: IOS-{projectId} 1개)
    private var fixedTopics: [String] = []

    private override init() {
        super.init()
    }

    private var coreProvider: AppBoxPushCoreProviding? {
        AppBoxPushCoreProviderRegistry.shared.provider ?? pushOnlyCoreProvider
    }

    private func logMissingCoreProvider(_ functionName: String = #function) {
        debugLog("\(functionName): AppBoxCoreSDK provider가 설정되지 않음")
    }

    private func appBoxPushError(code: Int, message: String) -> NSError {
        NSError(domain: "AppBoxPushSDK", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func performOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func isFixedTopic(_ topic: String) -> Bool {
        if fixedTopics.contains(topic) {
            return true
        }

        guard let projectId = coreProvider?.getProjectId()?.trimmingCharacters(in: .whitespacesAndNewlines),
              let currentFixedTopic = fixedTopic(for: projectId) else {
            return false
        }

        return topic == currentFixedTopic
    }
    
    /// 단독 푸시 고객사용 초기화 진입점입니다. debugMode 기본값은 false입니다.
    func initSDK(projectId: String?) {
        initSDK(projectId: projectId, debugMode: false)
    }

    /// 단독 푸시 고객사용 초기화 진입점입니다.
    /// AppBoxSDK provider가 없는 앱에서도 PushSDK 내부 Core provider를 구성해 token/click API가 동작하게 합니다.
    func initSDK(projectId: String?, debugMode: Bool) {
        initSDK(projectId: projectId, debugMode: debugMode, autoRegisterForAPNS: true, completion: nil)
    }

    /// completion을 지원하는 초기화 진입점입니다. debugMode 기본값은 false입니다.
    func initSDK(projectId: String?, completion: InitSDKCompletion?) {
        initSDK(projectId: projectId, debugMode: false, autoRegisterForAPNS: true, completion: completion)
    }

    /// completion을 지원하는 초기화 진입점입니다. autoRegisterForAPNS 기본값은 true입니다.
    func initSDK(projectId: String?, debugMode: Bool, completion: InitSDKCompletion?) {
        initSDK(projectId: projectId, debugMode: debugMode, autoRegisterForAPNS: true, completion: completion)
    }

    /// completion과 APNS 자동 등록 옵션을 지원하는 초기화 진입점입니다.
    func initSDK(
        projectId: String?,
        debugMode: Bool,
        autoRegisterForAPNS: Bool,
        completion: InitSDKCompletion?
    ) {
        let trimmedProjectId = projectId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedProjectId.isEmpty else {
            debugLog("initSDK: projectId is empty")
            performOnMain {
                completion?(
                    nil,
                    self.appBoxPushError(code: -1001, message: "projectId is empty"),
                    nil
                )
            }
            return
        }

        pushOnlyCoreProvider.configure(projectId: trimmedProjectId, debugMode: debugMode)
        fixedTopics = fixedTopic(for: trimmedProjectId).map { [$0] } ?? []
        appBoxPushInitWithLauchOptions(autoRegisterForAPNS: autoRegisterForAPNS, completion: completion)
    }

    /// Firebase push 설정을 초기화하고 고정 topic 상태를 준비합니다.
    /// AppBoxSDK에서 provider를 주입한 경우와 push-only provider를 사용하는 경우를 모두 처리합니다.
    func appBoxPushInitWithLauchOptions() {
        appBoxPushInitWithLauchOptions(autoRegisterForAPNS: true, completion: nil)
    }

    private func appBoxPushInitWithLauchOptions(
        autoRegisterForAPNS: Bool,
        completion: InitSDKCompletion?
    ) {
        guard let coreProvider = coreProvider else {
            logMissingCoreProvider()
            performOnMain {
                completion?(
                    nil,
                    self.appBoxPushError(code: -1002, message: "AppBoxCoreSDK provider is not configured"),
                    nil
                )
            }
            return
        }

        guard let projectId = coreProvider.getProjectId()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !projectId.isEmpty else {
            performOnMain {
                completion?(
                    nil,
                    self.appBoxPushError(code: -1001, message: "projectId is empty"),
                    nil
                )
            }
            return
        }

        // 고정토픽: IOS-{projectId}
        fixedTopics = fixedTopic(for: projectId).map { [$0] } ?? []

        if FirebaseApp.app() != nil {
            debugLog("appBoxPushInitWithLauchOptions: Firebase 이미 초기화됨")
            completeInitSuccess(autoRegisterForAPNS: autoRegisterForAPNS, completion: completion)
            return
        }
        
        if isInitializing {
            debugLog("appBoxPushInitWithLauchOptions: 초기화 진행 중")
            performOnMain {
                completion?(
                    nil,
                    self.appBoxPushError(code: -1003, message: "initSDK is already in progress"),
                    nil
                )
            }
            return
        }
        
        isInitializing = true
        debugLog("appBoxPushInitWithLauchOptions: 초기화 시작")
        
        coreProvider.getPushInfo(projectId) { [weak self] isSuccess, model in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isInitializing = false

                if isSuccess {
                    guard let info = model else {
                        debugLog("appBoxPushInitWithLauchOptions: Firebase 정보 없음")
                        completion?(
                            nil,
                            self.appBoxPushError(code: -1004, message: "Firebase information is missing"),
                            nil
                        )
                        return
                    }
                    
                    let options = FirebaseOptions(
                        googleAppID: info.app_id,
                        gcmSenderID: info.sender_id
                    )
                    options.apiKey = info.api_key
                    options.projectID = info.project_id
                    
                    // 설정된 clientID 사용
                    if let clientID = AppBoxPushRepository.firebaseClientID {
                        options.clientID = clientID
                        debugLog("appBoxPushInitWithLauchOptions: 설정된 Firebase Client ID 사용")
                    } else {
                        debugLog("appBoxPushInitWithLauchOptions: Firebase Client ID가 설정되지 않음, clientID 없이 초기화 진행")
                    }
                    
                    FirebaseApp.configure(options: options)
                    debugLog("appBoxPushInitWithLauchOptions: Firebase 초기화 완료")
                    self.completeInitSuccess(autoRegisterForAPNS: autoRegisterForAPNS, completion: completion)
                } else {
                    debugLog("appBoxPushInitWithLauchOptions: Firebase 초기화 실패")
                    completion?(
                        nil,
                        self.appBoxPushError(code: -1005, message: "Firebase initialization failed"),
                        nil
                    )
                }
            }
        }
    }

    private func completeInitSuccess(autoRegisterForAPNS: Bool, completion: InitSDKCompletion?) {
        performOnMain {
            let result = AppBoxNotiResultModel(token: "", message: "initSDK init Success.")
            guard autoRegisterForAPNS else {
                completion?(result, nil, nil)
                return
            }

            self.requestPushAuthorization { granted in
                completion?(result, nil, NSNumber(value: granted))
            }
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    
    /// 실제 알림 권한 상태를 확인하고, notDetermined이면 시스템 권한 팝업을 요청합니다.
    private func appBoxPushRequestPermissionForNotifications(completion: @escaping (Bool) -> Void) {
        let options: UNAuthorizationOptions = [.badge, .alert, .sound]
        
        
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    //허용
                    completion(true)
                case .denied:
                    //거부
                    completion(false)
                case .notDetermined:
                    // 권한 요청 안함
                    self.center.requestAuthorization(options: options) { granted, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                debugLog("Error requesting notification authorization: \(error.localizedDescription)")
                            }

                            completion(granted)
                        }
                    }
                @unknown default:
                    //알 수없는 상태
                    completion(false)
                }
            }
        }
    }

    /// public 권한 요청 wrapper입니다. ObjC selector `requestPushAuthorization:`로 노출됩니다.
    func requestPushAuthorization(completion: @escaping (Bool) -> Void) {
        appBoxPushRequestPermissionForNotifications(completion: completion)
    }
    
    /// APNs token을 Firebase Messaging에 전달한 뒤 FCM token을 서버에 저장합니다.
    func appBoxPushApnsToken(apnsToken: Data) {
        application(didRegisterForRemoteNotificationsWithDeviceToken: apnsToken, completion: nil)
    }

    /// APNs device token을 전달하고 FCM token 저장 흐름을 실행합니다.
    func application(didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        application(didRegisterForRemoteNotificationsWithDeviceToken: deviceToken, completion: nil)
    }

    /// APNs device token을 전달하고 FCM token 저장 결과를 반환합니다.
    func application(
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data,
        completion: PushTokenCompletion?
    ) {
        guard let _ = FirebaseApp.app() else {
            debugLog("push init fail")
            performOnMain {
                completion?(
                    nil,
                    self.appBoxPushError(code: -1006, message: "Firebase is not initialized")
                )
            }
            return
        }
        Messaging.messaging().apnsToken = deviceToken

        self.appBoxPushRequestPermissionForNotifications { _ in
            Messaging.messaging().token { token, error in
                guard let coreProvider = self.coreProvider else {
                    self.logMissingCoreProvider()
                    self.performOnMain {
                        completion?(
                            nil,
                            self.appBoxPushError(code: -1002, message: "AppBoxCoreSDK provider is not configured")
                        )
                    }
                    return
                }

                let pushToken = token ?? coreProvider.getPushToken() ?? ""

                if let error = error, pushToken.isEmpty {
                    debugLog("appBoxPushApnsToken: FCM token fetch failed - \(error.localizedDescription)")
                    self.performOnMain {
                        completion?(nil, error as NSError)
                        self.delegate?.appBoxPushTokenDidUpdate?(self.getPushToken())
                    }
                    return
                }

                debugLog("save token :: \(String(describing: pushToken))")
                coreProvider.setPushToken(pushToken, pushYn: "") { apiSuccess in
                    self.performOnMain {
                        if apiSuccess {
                            self.processFixedTopicsIfNeeded()
                            completion?(AppBoxNotiResultModel(token: pushToken, message: ""), nil)
                        } else {
                            debugLog("appBoxPushApnsToken: push token 등록 실패, 고정 토픽 처리를 건너뜀")
                            completion?(
                                nil,
                                self.appBoxPushError(code: -1007, message: "push token save failed")
                            )
                        }
                        self.delegate?.appBoxPushTokenDidUpdate?(self.getPushToken())
                    }
                }
            }
        }
    }
    
    func appBoxPushSendToken(pushYn: String, completion: @escaping (Bool, Bool) -> Void) {
        guard let _ = FirebaseApp.app() else {
            debugLog("push init fail")
            completion(false, false)
            return
        }
        if pushYn == "Y" {
            self.appBoxPushRequestPermissionForNotifications { permissionResult in
                if !permissionResult {
                    // 권한이 없으면 API 호출하지 않고 즉시 반환
                    completion(false, false)
                    return
                }

                // 권한이 있으면 API 호출
                Messaging.messaging().token { token, error in
                    guard let coreProvider = self.coreProvider else {
                        self.logMissingCoreProvider()
                        completion(false, false)
                        return
                    }

                    debugLog("new Token :: \(String(describing: token))")
                    let pushToken = token ?? coreProvider.getPushToken() ?? ""

                    coreProvider.setPushToken(pushToken, pushYn: pushYn) { apiSuccess in
                        if apiSuccess {
                            self.syncFixedTopics(pushYn: pushYn)
                        }
                        completion(true, apiSuccess)
                    }
                }
            }
        } else {
            // pushYn이 "N"이면 권한 체크 없이 API만 호출
            Messaging.messaging().token { token, error in
                guard let coreProvider = self.coreProvider else {
                    self.logMissingCoreProvider()
                    completion(false, false)
                    return
                }

                let pushToken = token ?? coreProvider.getPushToken() ?? ""
                coreProvider.setPushToken(pushToken, pushYn: pushYn) { apiSuccess in
                    if apiSuccess {
                        self.syncFixedTopics(pushYn: pushYn)
                    }
                    completion(true, apiSuccess)
                }
            }
        }
    }

    /// 고객사가 자체 저장소에 보관한 FCM token을 직접 넘기는 mixed project 전환을 지원합니다.
    func savePushToken(token: String, pushYn: Bool) {
        savePushToken(token: token, pushYn: pushYn, completion: nil)
    }

    /// 외부에서 보관한 FCM token과 push 동의값을 저장합니다.
    /// completion과 delegate callback은 main thread에서 호출합니다.
    func savePushToken(token: String, pushYn: Bool, completion: PushTokenCompletion?) {
        let pushYnValue = pushYn ? "Y" : "N"
        guard let coreProvider = coreProvider else {
            logMissingCoreProvider()
            performOnMain {
                completion?(
                    nil,
                    self.appBoxPushError(code: -1002, message: "AppBoxCoreSDK provider is not configured")
                )
            }
            return
        }

        coreProvider.setPushToken(token, pushYn: pushYnValue) { [weak self] apiSuccess in
            guard let self = self else { return }
            self.performOnMain {
                if apiSuccess {
                    self.syncFixedTopics(pushYn: pushYnValue)
                    completion?(AppBoxNotiResultModel(token: token, message: ""), nil)
                } else {
                    debugLog("savePushToken: push token 등록 실패")
                    completion?(
                        nil,
                        self.appBoxPushError(code: -1007, message: "push token save failed")
                    )
                }
                self.delegate?.appBoxPushTokenDidUpdate?(self.getPushToken())
            }
        }
    }

    /// SDK가 마지막으로 저장한 FCM token을 반환합니다.
    func getPushToken() -> String? {
        coreProvider?.getPushToken()
    }

    /// push payload의 param 값을 AppBoxNotiModel로 변환합니다.
    /// payload에 idx와 param이 모두 있을 때 param 값을 AppBoxNotiModel.params로 제공합니다.
    func receiveNotiModel(_ response: UNNotificationResponse) -> AppBoxNotiModel? {
        let userInfo = response.notification.request.content.userInfo
        guard let _ = pushPayloadString(userInfo["idx"]),
              let param = pushPayloadString(userInfo["param"]) else {
            return nil
        }
        return AppBoxNotiModel(params: param)
    }

    /// 푸시 클릭 통계와 conversion metadata 저장을 함께 수행합니다.
    /// provider에는 pushIdx 단독이 아니라 userInfo 전체를 넘겨 push payload 기반 동작을 유지합니다.
    func saveNotiClick(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        guard let pushIdx = pushPayloadString(userInfo["idx"]) else {
            debugLog("saveNotiClick: idx not found, skip")
            return
        }

        guard markPushClickIfNeeded(pushIdx) else {
            debugLog("saveNotiClick: duplicate, skip - pushIdx=\(pushIdx)")
            return
        }

        if let meta = ConversionMeta(userInfo: userInfo) {
            ConversionMetadataStore.shared.save(meta)
        }

        guard let coreProvider = coreProvider else {
            logMissingCoreProvider()
            return
        }

        coreProvider.savePushClick(userInfo: userInfo) { success in
            if success {
                debugLog("saveNotiClick: success - pushIdx=\(pushIdx)")
            } else {
                debugLog("saveNotiClick: failed - pushIdx=\(pushIdx)")
            }
        }
    }
    
    func createFCMImage(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }

        guard let imageURLString = notificationImageURLString(from: request.content.userInfo),
              let imageURL = URL(string: imageURLString) else {
            contentHandler(bestAttemptContent)
            return
        }

        URLSession.shared.downloadTask(with: imageURL) { downloadedURL, response, error in
            defer {
                contentHandler(bestAttemptContent)
            }

            if let error = error {
                debugLog("createFCMImage: image download failed - \(error.localizedDescription)")
                return
            }

            guard let downloadedURL = downloadedURL else {
                debugLog("createFCMImage: downloaded file URL is nil")
                return
            }

            let fileExtension = self.notificationImageFileExtension(for: imageURL, response: response)
            let localURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            do {
                try FileManager.default.moveItem(at: downloadedURL, to: localURL)
                let attachment = try UNNotificationAttachment(
                    identifier: "appbox_notification_attachment",
                    url: localURL,
                    options: nil
                )
                bestAttemptContent.attachments = [attachment]
            } catch {
                debugLog("createFCMImage: attachment failed - \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - Segment / Conversion

    func saveSegment(segment: [String: String]) {
        saveSegment(segment: segment, completion: nil)
    }

    func saveSegment(
        segment: [String: String],
        completion: ((AppBoxNotiResultModel?, NSError?) -> Void)?
    ) {
        guard let coreProvider = coreProvider else {
            logMissingCoreProvider()
            performOnMain {
                completion?(
                    nil,
                    self.appBoxPushError(code: -1002, message: "AppBoxCoreSDK provider is not configured")
                )
            }
            return
        }

        coreProvider.saveSegment(segment) { [weak self] success, error in
            guard let self = self else { return }
            self.performOnMain {
                if success {
                    completion?(AppBoxNotiResultModel(token: "", message: "save Success"), nil)
                } else {
                    completion?(
                        nil,
                        error ?? self.appBoxPushError(code: -1008, message: "segment save failed")
                    )
                }
            }
        }
    }

    func trackingConversion(conversionCode: String) {
        trackingConversion(conversionCode: conversionCode, completion: nil)
    }

    func trackingConversion(
        conversionCode: String,
        completion: ((Bool, NSError?) -> Void)?
    ) {
        let trimmed = conversionCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            performOnMain {
                completion?(
                    false,
                    self.appBoxPushError(code: -1009, message: "conversionCode is empty")
                )
            }
            return
        }

        guard let coreProvider = coreProvider else {
            logMissingCoreProvider()
            performOnMain {
                completion?(
                    false,
                    self.appBoxPushError(code: -1002, message: "AppBoxCoreSDK provider is not configured")
                )
            }
            return
        }

        coreProvider.trackConversion(conversionCode: trimmed) { [weak self] success, error in
            self?.performOnMain {
                completion?(success, error)
            }
        }
    }

    // MARK: - Topic Subscribe/Unsubscribe

    func subscribeToTopic(_ topic: String, completion: ((Bool, NSError?) -> Void)?) {
        sendTopicEvent(eventType: "SUBSCRIBE", topic: topic, completion: completion)
    }

    func subscribeToTopic(_ topic: String) {
        subscribeToTopic(topic, completion: nil)
    }

    func unsubscribeFromTopic(_ topic: String, completion: ((Bool, NSError?) -> Void)?) {
        sendTopicEvent(eventType: "UNSUBSCRIBE", topic: topic, completion: completion)
    }

    func unsubscribeFromTopic(_ topic: String) {
        unsubscribeFromTopic(topic, completion: nil)
    }

    private func sendTopicEvent(
        eventType: String,
        topic: String,
        completion: ((_ success: Bool, _ error: NSError?) -> Void)?
    ) {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxTopicLength,
              trimmed.range(of: topicRegex, options: .regularExpression) != nil else {
            performOnMain {
                completion?(
                    false,
                    self.appBoxPushError(code: -1010, message: "invalid topic")
                )
            }
            return
        }

        guard !isFixedTopic(trimmed) else {
            performOnMain {
                completion?(
                    false,
                    self.appBoxPushError(code: -1011, message: "fixed topic cannot be changed")
                )
            }
            return
        }

        guard let coreProvider = coreProvider else {
            logMissingCoreProvider()
            performOnMain {
                completion?(
                    false,
                    self.appBoxPushError(code: -1002, message: "AppBoxCoreSDK provider is not configured")
                )
            }
            return
        }

        coreProvider.fetchSubscribableTopics(eventType: eventType, topics: [trimmed]) { [weak self] success, topics, error in
            guard let self = self else { return }
            guard success, topics.contains(trimmed) else {
                self.performOnMain {
                    completion?(
                        false,
                        error ?? self.appBoxPushError(code: -1012, message: "topic is not allowed")
                    )
                }
                return
            }

            self.fcmTopic(eventType: eventType, topic: trimmed) { fcmSuccess in
                guard fcmSuccess else {
                    self.performOnMain {
                        completion?(
                            false,
                            self.appBoxPushError(code: -1013, message: "FCM \(eventType) failed")
                        )
                    }
                    return
                }

                coreProvider.sendPushTopicCallback(eventType: eventType, topics: [trimmed]) { callbackSuccess, callbackError in
                    guard callbackSuccess else {
                        let rollbackType = eventType == "SUBSCRIBE" ? "UNSUBSCRIBE" : "SUBSCRIBE"
                        self.fcmTopic(eventType: rollbackType, topic: trimmed) { _ in
                            self.performOnMain {
                                completion?(
                                    false,
                                    callbackError ?? self.appBoxPushError(code: -1014, message: "topic callback failed")
                                )
                            }
                        }
                        return
                    }

                    self.performOnMain {
                        completion?(true, nil)
                    }
                }
            }
        }
    }

    private func fcmTopic(eventType: String, topic: String, completion: @escaping (Bool) -> Void) {
        if eventType == "SUBSCRIBE" {
            Messaging.messaging().subscribe(toTopic: topic) { error in
                completion(error == nil)
            }
        } else {
            Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                completion(error == nil)
            }
        }
    }

    private func notificationImageURLString(from userInfo: [AnyHashable: Any]) -> String? {
        if let fcmOptions = userInfo["fcm_options"] as? [String: Any],
           let image = fcmOptions["image"] as? String,
           !image.isEmpty {
            return image
        }

        if let fcmOptions = userInfo["fcm_options"] as? [AnyHashable: Any],
           let image = fcmOptions["image"] as? String,
           !image.isEmpty {
            return image
        }

        if let imageURL = userInfo["imageUrl"] as? String,
           !imageURL.isEmpty {
            return imageURL
        }

        return nil
    }

    private func notificationImageFileExtension(for imageURL: URL, response: URLResponse?) -> String {
        let pathExtension = imageURL.pathExtension
        if !pathExtension.isEmpty {
            return pathExtension
        }

        switch response?.mimeType?.lowercased() {
        case "image/jpeg", "image/jpg":
            return "jpg"
        case "image/gif":
            return "gif"
        case "image/webp":
            return "webp"
        default:
            return "png"
        }
    }

    /// push payload의 String/NSNumber 값을 공통 문자열 형태로 정규화합니다.
    private func pushPayloadString(_ value: Any?) -> String? {
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

    /// 동일 pushIdx 클릭 통계가 한 프로세스에서 중복 전송되지 않도록 막습니다.
    private func markPushClickIfNeeded(_ pushIdx: String) -> Bool {
        processedPushClickIdsLock.lock()
        defer { processedPushClickIdsLock.unlock() }

        guard !processedPushClickIds.contains(pushIdx) else {
            return false
        }

        processedPushClickIds.insert(pushIdx)
        return true
    }
    
    func appBoxSetSegment(segment: [String : String], completion: @escaping (Bool) -> Void) {
        saveSegment(segment: segment) { _, error in
            completion(error == nil)
        }
    }
    
    // MARK: - Topic Methods

    func appBoxPushSubscribeTopic(_ topic: String, source: String, completion: @escaping (Bool, Int, String) -> Void) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            DispatchQueue.main.async {
                if let error = error {
                    debugLog("subscribeTopic: FCM 구독 실패 - topic=\(topic), error=\(error)")
                    completion(false, -1, "FCM 구독 실패")
                    return
                }
                debugLog("subscribeTopic: FCM 구독 완료 - topic=\(topic), source=\(source)")
                completion(true, 0, "구독 완료")
            }
        }
    }

    func appBoxPushUnsubscribeTopic(_ topic: String, source: String, completion: @escaping (Bool, Int, String) -> Void) {
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            DispatchQueue.main.async {
                if let error = error {
                    debugLog("unsubscribeTopic: FCM 해제 실패 - topic=\(topic), error=\(error)")
                    completion(false, -1, "FCM 해제 실패")
                    return
                }
                debugLog("unsubscribeTopic: FCM 해제 완료 - topic=\(topic), source=\(source)")
                completion(true, 0, "해제 완료")
            }
        }
    }

    // MARK: - Fixed Topic

    private func fixedTopic(for projectId: String) -> String? {
        guard !projectId.isEmpty else { return nil }
        return "IOS-\(projectId)"
    }

    private func makeFixedTopicSignature(topics: [String]) -> String {
        let normalizedTopics = topics
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()

        return "\(fixedTopicSignatureVersion)|topics=\(normalizedTopics.joined(separator: ","))"
    }

    private func sendFixedTopicCallback(eventType: String, topic: String, completion: ((Bool) -> Void)? = nil) {
        guard let coreProvider = coreProvider else {
            logMissingCoreProvider()
            completion?(false)
            return
        }

        coreProvider.sendPushTopicCallback(eventType: eventType, topic: topic) { success in
            if success {
                debugLog("sendFixedTopicCallback: 완료 - type=\(eventType), topic=\(topic)")
            } else {
                debugLog("sendFixedTopicCallback: 실패 - type=\(eventType), topic=\(topic)")
            }
            completion?(success)
        }
    }

    /// Firebase 초기화 완료 후 호출 - 고정 토픽 규칙 signature 기반으로 구독 보장
    private func processFixedTopicsIfNeeded() {
        guard !fixedTopics.isEmpty else {
            debugLog("processFixedTopics: 고정 토픽 없음")
            return
        }

        let currentSignature = makeFixedTopicSignature(topics: fixedTopics)
        guard fixedTopicSignature != currentSignature else {
            debugLog("processFixedTopics: 이미 처리됨(signature=\(currentSignature)), 스킵")
            return
        }

        debugLog("processFixedTopics: 시작 - signature=\(currentSignature), topics=\(fixedTopics), subscribe=true")

        let group = DispatchGroup()
        let lock = NSLock()
        var allSuccess = true

        for topic in fixedTopics {
            group.enter()
            Messaging.messaging().subscribe(toTopic: topic) { error in
                if let error = error {
                    lock.lock(); allSuccess = false; lock.unlock()
                    debugLog("processFixedTopics: FCM 구독 실패 - topic=\(topic), error=\(error)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            guard allSuccess else {
                debugLog("processFixedTopics: 일부 실패, 다음 실행 시 재시도 (fixedTopicSignature 미저장)")
                return
            }

            guard let topic = self.fixedTopics.first else {
                self.fixedTopicSignature = currentSignature
                debugLog("processFixedTopics: 완료 - signature=\(currentSignature), topics=\(self.fixedTopics)")
                return
            }

            self.sendFixedTopicCallback(eventType: "SUBSCRIBE", topic: topic) { callbackSuccess in
                guard callbackSuccess else {
                    debugLog("processFixedTopics: callback 실패, 다음 실행 시 재시도 (fixedTopicSignature 미저장)")
                    return
                }
                self.fixedTopicSignature = currentSignature
                debugLog("processFixedTopics: 완료 - signature=\(currentSignature), topics=\(self.fixedTopics)")
            }
        }
    }

    /// pushYN 변경 시 고정 토픽 즉시 동기화 (성공 시 legacy pushYN과 topic signature 저장, 실패 시 미저장으로 재실행 시 재시도)
    private func syncFixedTopics(pushYn: String) {
        guard !fixedTopics.isEmpty else { return }

        let shouldSubscribe = (pushYn == "Y")
        let currentSignature = makeFixedTopicSignature(topics: fixedTopics)
        debugLog("syncFixedTopics: 시작 - pushYN=\(pushYn), topics=\(fixedTopics), subscribe=\(shouldSubscribe)")

        let group = DispatchGroup()
        let lock = NSLock()
        var allSuccess = true

        for topic in fixedTopics {
            group.enter()
            if shouldSubscribe {
                Messaging.messaging().subscribe(toTopic: topic) { error in
                    if let error = error {
                        lock.lock(); allSuccess = false; lock.unlock()
                        debugLog("syncFixedTopics: FCM 구독 실패 - topic=\(topic), error=\(error)")
                    }
                    group.leave()
                }
            } else {
                Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                    if let error = error {
                        lock.lock(); allSuccess = false; lock.unlock()
                        debugLog("syncFixedTopics: FCM 해제 실패 - topic=\(topic), error=\(error)")
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            guard allSuccess else {
                debugLog("syncFixedTopics: 일부 실패, 다음 실행 시 재시도 (상태 미저장)")
                return
            }

            guard let topic = self.fixedTopics.first else {
                self.lastAppliedPushYn = pushYn
                if shouldSubscribe {
                    self.fixedTopicSignature = currentSignature
                }
                debugLog("syncFixedTopics: 완료 - pushYN=\(pushYn), topics=\(self.fixedTopics)")
                return
            }

            let eventType = shouldSubscribe ? "SUBSCRIBE" : "UNSUBSCRIBE"
            self.sendFixedTopicCallback(eventType: eventType, topic: topic) { callbackSuccess in
                guard callbackSuccess else {
                    debugLog("syncFixedTopics: callback 실패, 다음 실행 시 재시도 (상태 미저장)")
                    return
                }
                self.lastAppliedPushYn = pushYn
                if shouldSubscribe {
                    self.fixedTopicSignature = currentSignature
                }
                debugLog("syncFixedTopics: 완료 - pushYN=\(pushYn), topics=\(self.fixedTopics)")
            }
        }
    }

    // MARK: - Initialization Methods

    @objc(initializeFirebaseClientID:)
    func initializeFirebaseClientID(clientID: String) {
        guard AppBoxPushRepository.firebaseClientID == nil else {
            debugLog("AppBoxPushRepository: Firebase Client ID가 이미 초기화됨")
            return
        }
        
        AppBoxPushRepository.firebaseClientID = clientID
        debugLog("AppBoxPushRepository: Firebase Client ID 초기화 완료")
    }
}
