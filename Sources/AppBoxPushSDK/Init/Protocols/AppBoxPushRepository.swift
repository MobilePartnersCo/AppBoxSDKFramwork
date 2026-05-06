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
    let center = UNUserNotificationCenter.current()

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
    
    /// 단독 푸시 고객사용 초기화 진입점입니다. debugMode 기본값은 false입니다.
    func initSDK(projectId: String) {
        initSDK(projectId: projectId, debugMode: false)
    }

    /// 단독 푸시 고객사용 초기화 진입점입니다.
    /// AppBoxSDK provider가 없는 앱에서도 PushSDK 내부 Core provider를 구성해 token/click API가 동작하게 합니다.
    func initSDK(projectId: String, debugMode: Bool) {
        let trimmedProjectId = projectId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProjectId.isEmpty else {
            debugLog("initSDK: projectId is empty")
            return
        }

        pushOnlyCoreProvider.configure(projectId: trimmedProjectId, debugMode: debugMode)
        fixedTopics = fixedTopic(for: trimmedProjectId).map { [$0] } ?? []
        appBoxPushInitWithLauchOptions()
    }

    /// Firebase push 설정을 초기화하고 고정 topic 상태를 준비합니다.
    /// AppBoxSDK에서 provider를 주입한 경우와 push-only provider를 사용하는 경우를 모두 처리합니다.
    func appBoxPushInitWithLauchOptions() {
        guard let coreProvider = coreProvider else {
            logMissingCoreProvider()
            return
        }

        guard let projectId = coreProvider.getProjectId() else {
            return
        }

        // 고정토픽: IOS-{projectId}
        let trimmedProjectId = projectId.trimmingCharacters(in: .whitespacesAndNewlines)
        fixedTopics = fixedTopic(for: trimmedProjectId).map { [$0] } ?? []

        if FirebaseApp.app() != nil {
            debugLog("appBoxPushInitWithLauchOptions: Firebase 이미 초기화됨")
            UIApplication.shared.registerForRemoteNotifications()
            return
        }
        
        if isInitializing {
            debugLog("appBoxPushInitWithLauchOptions: 초기화 진행 중")
            return
        }
        
        isInitializing = true
        debugLog("appBoxPushInitWithLauchOptions: 초기화 시작")
        
        coreProvider.getPushInfo(projectId) { [weak self] isSuccess, model in
            guard let self = self else { return }
            self.isInitializing = false
            
            DispatchQueue.main.async {
                if isSuccess {
                    guard let info = model else {
                        debugLog("appBoxPushInitWithLauchOptions: Firebase 정보 없음")
                        UIApplication.shared.registerForRemoteNotifications()
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
                    UIApplication.shared.registerForRemoteNotifications()
                    debugLog("appBoxPushInitWithLauchOptions: Firebase 초기화 완료")
                } else {
                    UIApplication.shared.registerForRemoteNotifications()
                    debugLog("appBoxPushInitWithLauchOptions: Firebase 초기화 실패")
                }
            }
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
        guard let _ = FirebaseApp.app() else {
            debugLog("push init fail")
            return
        }
        Messaging.messaging().apnsToken = apnsToken

        self.appBoxPushRequestPermissionForNotifications { result in
            Messaging.messaging().token { token, error in
                guard let coreProvider = self.coreProvider else {
                    self.logMissingCoreProvider()
                    return
                }

                let pushToken = token ?? coreProvider.getPushToken() ?? ""

                debugLog("save token :: \(String(describing: pushToken))")
                coreProvider.setPushToken(pushToken, pushYn: "") { apiSuccess in
                    guard apiSuccess else {
                        debugLog("appBoxPushApnsToken: push token 등록 실패, 고정 토픽 처리를 건너뜀")
                        return
                    }
                    self.processFixedTopicsIfNeeded()
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

    /// sendMessage 호환용 token 저장 API입니다.
    /// 고객사가 자체 저장소에 보관한 FCM token을 직접 넘기는 mixed project 전환을 지원합니다.
    func savePushToken(token: String, pushYn: Bool) {
        let pushYnValue = pushYn ? "Y" : "N"
        guard let coreProvider = coreProvider else {
            logMissingCoreProvider()
            return
        }

        coreProvider.setPushToken(token, pushYn: pushYnValue) { [weak self] apiSuccess in
            guard apiSuccess else {
                debugLog("savePushToken: push token 등록 실패")
                return
            }
            self?.syncFixedTopics(pushYn: pushYnValue)
        }
    }

    /// SDK가 마지막으로 저장한 FCM token을 반환합니다.
    func getPushToken() -> String? {
        coreProvider?.getPushToken()
    }

    /// sendMessage의 receiveNotiModel 호환 helper입니다.
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
    /// provider에는 pushIdx 단독이 아니라 userInfo 전체를 넘겨 sendMessage payload 기반 동작을 유지합니다.
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
        guard let coreProvider = coreProvider else {
            logMissingCoreProvider()
            completion(false)
            return
        }

        coreProvider.setSegment(segment) { success in
            completion(success)
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
