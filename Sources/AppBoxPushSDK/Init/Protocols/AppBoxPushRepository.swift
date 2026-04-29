//
//  AppBoxPushRepository.swift
//  appboxpush
//
//  Created by mobilePartners on 1/24/25.
//


import UIKit
import UserNotifications
@_spi(AppBoxPushSDK) import AppBoxCoreSDK
import Firebase

class AppBoxPushRepository: NSObject, AppBoxPushProtocol {

    static let shared = AppBoxPushRepository()
    let center = UNUserNotificationCenter.current()

    // 초기화 중복 호출 방지 플래그
    private var isInitializing = false

    // Firebase Client ID 저장
    private static var firebaseClientID: String?

    // MARK: - UserDefaults Keys (AppBoxPushSDK 전용)
    private let kLastAppliedPushYn = "appBox_lastAppliedPushYn" // 마지막으로 고정 토픽에 적용한 pushYN 값

    /// 마지막으로 고정 토픽에 적용한 pushYN ("Y"/"N"/nil)
    private var lastAppliedPushYn: String? {
        get { UserDefaults.standard.string(forKey: kLastAppliedPushYn) }
        set { UserDefaults.standard.set(newValue, forKey: kLastAppliedPushYn) }
    }

    /// 고정 토픽 목록 (규칙: projectId 1개)
    private var fixedTopics: [String] = []

    private override init() {
        super.init()
    }

    private var coreProvider: AppBoxPushCoreProviding? {
        AppBoxPushCoreProviderRegistry.shared.provider
    }

    private func logMissingCoreProvider(_ functionName: String = #function) {
        debugLog("\(functionName): AppBoxCoreSDK provider가 설정되지 않음")
    }
    
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
    
    
    private func appBoxPushRequestPermissionForNotifications(completion: @escaping (Bool) -> Void) {
        let options: UNAuthorizationOptions = [.badge, .alert, .sound]
        
        
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
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

    /// Firebase 초기화 완료 후 호출 - pushYN 기반으로 고정 토픽 구독/해제
    private func processFixedTopicsIfNeeded() {
        let currentPushYn = UserDefaults.standard.string(forKey: "appBox_pushYn") ?? "Y"

        guard lastAppliedPushYn != currentPushYn else {
            debugLog("processFixedTopics: 이미 처리됨(lastApplied=\(currentPushYn)), 스킵")
            return
        }

        guard !fixedTopics.isEmpty else {
            debugLog("processFixedTopics: 고정 토픽 없음")
            lastAppliedPushYn = currentPushYn
            return
        }

        let shouldSubscribe = (currentPushYn == "Y")
        debugLog("processFixedTopics: 시작 - pushYN=\(currentPushYn), topics=\(fixedTopics), subscribe=\(shouldSubscribe)")

        let group = DispatchGroup()
        let lock = NSLock()
        var allSuccess = true

        for topic in fixedTopics {
            group.enter()
            if shouldSubscribe {
                Messaging.messaging().subscribe(toTopic: topic) { error in
                    if let error = error {
                        lock.lock(); allSuccess = false; lock.unlock()
                        debugLog("processFixedTopics: FCM 구독 실패 - topic=\(topic), error=\(error)")
                    }
                    group.leave()
                }
            } else {
                Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                    if let error = error {
                        lock.lock(); allSuccess = false; lock.unlock()
                        debugLog("processFixedTopics: FCM 해제 실패 - topic=\(topic), error=\(error)")
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            guard allSuccess else {
                debugLog("processFixedTopics: 일부 실패, 다음 실행 시 재시도 (lastAppliedPushYn 미저장)")
                return
            }

            guard let topic = self.fixedTopics.first else {
                self.lastAppliedPushYn = currentPushYn
                debugLog("processFixedTopics: 완료 - pushYN=\(currentPushYn), topics=\(self.fixedTopics)")
                return
            }

            let eventType = shouldSubscribe ? "SUBSCRIBE" : "UNSUBSCRIBE"
            self.sendFixedTopicCallback(eventType: eventType, topic: topic) { callbackSuccess in
                guard callbackSuccess else {
                    debugLog("processFixedTopics: callback 실패, 다음 실행 시 재시도 (lastAppliedPushYn 미저장)")
                    return
                }
                self.lastAppliedPushYn = currentPushYn
                debugLog("processFixedTopics: 완료 - pushYN=\(currentPushYn), topics=\(self.fixedTopics)")
            }
        }
    }

    /// pushYN 변경 시 고정 토픽 즉시 동기화 (성공 시 lastAppliedPushYn 저장, 실패 시 미저장으로 재실행 시 재시도)
    private func syncFixedTopics(pushYn: String) {
        guard !fixedTopics.isEmpty else { return }

        let shouldSubscribe = (pushYn == "Y")
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
                debugLog("syncFixedTopics: 일부 실패, 다음 실행 시 재시도 (lastAppliedPushYn 미저장)")
                return
            }

            guard let topic = self.fixedTopics.first else {
                self.lastAppliedPushYn = pushYn
                debugLog("syncFixedTopics: 완료 - pushYN=\(pushYn), topics=\(self.fixedTopics)")
                return
            }

            let eventType = shouldSubscribe ? "SUBSCRIBE" : "UNSUBSCRIBE"
            self.sendFixedTopicCallback(eventType: eventType, topic: topic) { callbackSuccess in
                guard callbackSuccess else {
                    debugLog("syncFixedTopics: callback 실패, 다음 실행 시 재시도 (lastAppliedPushYn 미저장)")
                    return
                }
                self.lastAppliedPushYn = pushYn
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
