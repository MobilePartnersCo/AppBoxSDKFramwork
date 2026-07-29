import Foundation
import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

enum InappMessageNativeServiceResult: Equatable {
    case shown
    case queued
    case skipped(String)
    case failed(String)
}

protocol InappMessageSyncAPIClient {
    func sync(
        apiDomain: String,
        apiKey: Data,
        time: String,
        projectCode: String,
        appPackageId: String?,
        deviceUserId: String,
        syncVersion: String?,
        completion: @escaping (Result<CoreAPIResponse<InappMessageSyncAPIResponse>, Error>) -> Void
    )
}

protocol InappMessageContentAPIClient {
    func fetchContent(
        apiDomain: String,
        apiKey: Data,
        time: String,
        projectCode: String,
        campaignCode: String,
        appPackageId: String?,
        deviceUserId: String,
        etag: String?,
        lastModified: String?,
        completion: @escaping (Result<CoreAPIResponse<InappMessageContentAPIResponse>, Error>) -> Void
    )
}

protocol InappMessageSyncVersionStoring {
    func read(projectCode: String, appPackageId: String?, deviceUserId: String) -> String?
    func save(_ syncVersion: String, projectCode: String, appPackageId: String?, deviceUserId: String)
}

protocol InappMessageImpressionStoring {
    func recordImpression(campaignCode: String, now: Date)
    func setDontShowToday(campaignCode: String, now: Date)
    func isAllowedToShow(campaignCode: String, frequencyType: String, limit: Int?, now: Date) -> Bool
}

protocol InappMessageRendering {
    @MainActor
    func show(
        spec: InappMessageRenderSpec,
        from presenter: UIViewController,
        options: InappMessageLocalRendererOptions,
        completion: ((Result<Void, Error>) -> Void)?
    )
    @MainActor
    func dismiss(animated: Bool)
}

extension CoreInappMessageSyncApi: InappMessageSyncAPIClient {}
extension CoreInappMessageContentApi: InappMessageContentAPIClient {}
extension CoreInAppImpressionRepository: InappMessageImpressionStoring {}
extension InappMessageSyncVersionStore: InappMessageSyncVersionStoring {}

struct InappMessageLocalRenderingAdapter: InappMessageRendering {
    @MainActor
    func show(
        spec: InappMessageRenderSpec,
        from presenter: UIViewController,
        options: InappMessageLocalRendererOptions,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        InappMessageLocalRenderer.shared.show(spec: spec, from: presenter, options: options, completion: completion)
    }

    @MainActor
    func dismiss(animated: Bool) {
        InappMessageLocalRenderer.shared.dismiss(animated: animated)
    }
}

protocol InappMessageScheduledTask: AnyObject {
    func cancel()
}

protocol InappMessageScheduling {
    @discardableResult
    func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) -> InappMessageScheduledTask
}

private final class DispatchInappMessageScheduledTask: InappMessageScheduledTask {
    private let workItem: DispatchWorkItem

    init(workItem: DispatchWorkItem) {
        self.workItem = workItem
    }

    func cancel() {
        workItem.cancel()
    }
}

struct DispatchInappMessageScheduler: InappMessageScheduling {
    func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) -> InappMessageScheduledTask {
        let workItem = DispatchWorkItem(block: block)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        return DispatchInappMessageScheduledTask(workItem: workItem)
    }
}

private enum ExactSyncResolution: Equatable {
    case notSynced
    case metadataResolved
    case syncedNoChangeFallbackAllowed
    case fullListMissing
    case serverGateBlocked
    case syncFailed
}

private struct InappMessageLogicalQueueItem {
    enum Source {
        case immediate
        case publicShow
        case pushClick
        case silentPush
    }

    let campaignCode: String
    var campaign: InappMessageCampaign?
    let instanceId: String?
    let journeyId: Int?
    let nodeCode: String?
    let source: Source
    let receivedAt: Date
    var syncResolution: ExactSyncResolution
    let completion: ((InappMessageNativeServiceResult) -> Void)?

    var isExactRequest: Bool {
        source != .immediate
    }
}

private extension InappMessageLogicalQueueItem {
    func mergingMetadata(from request: InappMessageLogicalQueueItem) -> InappMessageLogicalQueueItem {
        InappMessageLogicalQueueItem(
            campaignCode: campaignCode,
            campaign: campaign ?? request.campaign,
            instanceId: request.instanceId ?? instanceId,
            journeyId: request.journeyId ?? journeyId,
            nodeCode: request.nodeCode ?? nodeCode,
            source: source,
            receivedAt: receivedAt,
            syncResolution: syncResolution == .notSynced ? request.syncResolution : syncResolution,
            completion: completion ?? request.completion
        )
    }
}

private struct InappMessageLogicalQueue {
    private var items = [InappMessageLogicalQueueItem]()

    var isEmpty: Bool {
        items.isEmpty
    }

    var first: InappMessageLogicalQueueItem? {
        items.first
    }

    mutating func enqueue(_ newItems: [InappMessageLogicalQueueItem]) {
        newItems.forEach { updateOrAppend($0) }
    }

    mutating func updateOrAppend(_ item: InappMessageLogicalQueueItem) {
        if let index = items.firstIndex(where: { $0.campaignCode == item.campaignCode }) {
            items[index] = items[index].mergingMetadata(from: item)
        } else {
            items.append(item)
        }
    }

    @discardableResult
    mutating func poll() -> InappMessageLogicalQueueItem? {
        guard !items.isEmpty else { return nil }
        return items.removeFirst()
    }

    mutating func clear() -> [InappMessageLogicalQueueItem] {
        let removed = items
        items.removeAll()
        return removed
    }

    mutating func updateExactRequests(_ update: (inout InappMessageLogicalQueueItem) -> Void) {
        for index in items.indices where items[index].isExactRequest {
            update(&items[index])
        }
    }
}

final class InappMessageNativeService {
    static let shared = InappMessageNativeService()

    private let syncApi: InappMessageSyncAPIClient
    private let contentApi: InappMessageContentAPIClient
    private let campaignRepository: InappMessageCampaignRepositoryProtocol
    private let contentRepository: InappMessageContentRepositoryProtocol
    private let impressionRepository: InappMessageImpressionStoring
    private let eventReporter: InappMessageEventReporter
    private let triggerEngine: InappMessageTriggerEngine
    private let environment: AppBoxInappMessageEnvironmentProviding
    private let renderer: InappMessageRendering
    private let stateQueue = DispatchQueue(label: "kr.co.mobpa.appbox.inappMessageNativeService")
    private let syncVersionStore: InappMessageSyncVersionStoring
    private let scheduler: InappMessageScheduling

    private static let silentPushDedupeWindow: TimeInterval = 2
    private static let foregroundSyncThrottleWindow: TimeInterval = 10
    private static let maxDisplayDelay: TimeInterval = 10
    private static let serverDisplayGateBlockedReason = "server_gate_blocked"
    private static let campaignAlreadyDisplayingReason = "campaign_already_displaying"

    private var isSyncing = false
    private var isDrainingLogicalQueue = false
    private var isDisplayingLogicalItem = false
    private var isDisplayScreenActive = false
    private var isDisplayScreenReady = false
    private var isServerDisplayGateAllowed = true
    private var displaySessionId = 0
    private var pendingLogicalQueue = InappMessageLogicalQueue()
    private var pendingDisplayActivation: InappMessageScheduledTask?
    private var pendingDisplayActivationDelay: TimeInterval?
    private var actionListener: AppBoxInappMessageActionListener?
    private var lastScreen: String?
    private var lastURL: String?
    private var lastSilentPushSignature: String?
    private var lastSilentPushAt: Date?
    private var lastForegroundSyncAt: Date?
    private var didEnterBackgroundSinceLastActive = false
    private var restoreDisplaySessionAfterBackground = false
    private var restoreDisplaySessionWasReady = false
    private var restoreDisplayDelayAfterBackground: TimeInterval?
    private var foregroundRestorePendingSyncSessionId: Int?
    private var currentDisplayingCampaignCode: String?

    init(
        syncApi: InappMessageSyncAPIClient = CoreInappMessageSyncApi(),
        contentApi: InappMessageContentAPIClient = CoreInappMessageContentApi(),
        campaignRepository: InappMessageCampaignRepositoryProtocol = InappMessageCampaignRepository(coreDataManager: CoreDataManager.shared),
        contentRepository: InappMessageContentRepositoryProtocol = InappMessageContentRepository(coreDataManager: CoreDataManager.shared),
        impressionRepository: InappMessageImpressionStoring = CoreInAppImpressionRepository(coreDataManager: CoreDataManager.shared),
        eventReporter: InappMessageEventReporter = .shared,
        triggerEngine: InappMessageTriggerEngine = InappMessageTriggerEngine(),
        environment: AppBoxInappMessageEnvironmentProviding = AppBoxInappMessageEnvironment.shared,
        renderer: InappMessageRendering = InappMessageLocalRenderingAdapter(),
        syncVersionStore: InappMessageSyncVersionStoring = InappMessageSyncVersionStore.shared,
        scheduler: InappMessageScheduling = DispatchInappMessageScheduler()
    ) {
        self.syncApi = syncApi
        self.contentApi = contentApi
        self.campaignRepository = campaignRepository
        self.contentRepository = contentRepository
        self.impressionRepository = impressionRepository
        self.eventReporter = eventReporter
        self.triggerEngine = triggerEngine
        self.environment = environment
        self.renderer = renderer
        self.syncVersionStore = syncVersionStore
        self.scheduler = scheduler
        AppBoxInappMessagePushHandlerRegistry.shared.handler = self
    }

    func bootstrap() {
        campaignRepository.deleteExpired(now: Date())
        contentRepository.deleteExpired(now: Date())
        eventReporter.flushPending()
        sync(evaluateImmediate: false, completion: nil)
    }

    func handleDidBecomeActive() {
        eventReporter.flushPending()
        stateQueue.async {
            guard self.didEnterBackgroundSinceLastActive else { return }
            self.didEnterBackgroundSinceLastActive = false
            let restoredSessionId = self.restoreDisplaySessionAfterBackgroundOnStateQueue()
            let restoredSessionIsReady = restoredSessionId != nil && self.isDisplayScreenReady
            let now = Date()
            if let lastForegroundSyncAt = self.lastForegroundSyncAt,
               now.timeIntervalSince(lastForegroundSyncAt) < Self.foregroundSyncThrottleWindow {
                if restoredSessionIsReady {
                    self.evaluateTriggerOnStateQueue(InappMessageTriggerRequest(trigger: .immediate))
                }
                return
            }
            self.lastForegroundSyncAt = now
            if let restoredSessionId, restoredSessionIsReady {
                self.foregroundRestorePendingSyncSessionId = restoredSessionId
            }
            self.sync(
                evaluateImmediate: restoredSessionId != nil,
                sessionId: restoredSessionId,
                completion: nil
            )
        }
    }

    func handleDidEnterBackground() {
        stateQueue.async {
            self.didEnterBackgroundSinceLastActive = true
            self.captureDisplaySessionForBackgroundRestoreOnStateQueue()
            self.endDisplaySessionOnStateQueue()
            self.clearLogicalQueueOnStateQueue(reason: "app_background")
        }
        Task { @MainActor in
            renderer.dismiss(animated: false)
        }
    }

    func sync(completion: ((Bool, Error?) -> Void)?) {
        sync(evaluateImmediate: false, completion: completion)
    }

    func enterDisplayScreen(delay: TimeInterval = 0) {
        let normalizedDelay = Self.normalizedDisplayDelay(delay)
        stateQueue.async {
            self.clearBackgroundRestoreStateOnStateQueue()
            self.pendingDisplayActivation?.cancel()
            self.pendingDisplayActivationDelay = nil
            self.displaySessionId &+= 1
            let sessionId = self.displaySessionId
            self.isDisplayScreenActive = true
            self.isDisplayScreenReady = false

            guard normalizedDelay > 0 else {
                self.activateDisplaySessionOnStateQueue(sessionId: sessionId)
                return
            }

            self.pendingDisplayActivationDelay = normalizedDelay
            self.pendingDisplayActivation = self.scheduler.schedule(after: normalizedDelay) { [weak self] in
                self?.stateQueue.async {
                    self?.activateDisplaySessionOnStateQueue(sessionId: sessionId)
                }
            }
        }
    }

    func leaveDisplayScreen() {
        stateQueue.async {
            self.clearBackgroundRestoreStateOnStateQueue()
            self.endDisplaySessionOnStateQueue()
            self.clearLogicalQueueOnStateQueue(reason: "display_screen_left")
        }
        Task { @MainActor in
            renderer.dismiss(animated: false)
        }
    }

    func show(
        campaignCode: String,
        instanceId: String? = nil,
        journeyId: Int? = nil,
        nodeCode: String? = nil,
        completion: ((InappMessageNativeServiceResult) -> Void)? = nil
    ) {
        let trimmedCode = campaignCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            completion?(.skipped("campaign_code_empty"))
            return
        }
        enqueueLogicalItem(InappMessageLogicalQueueItem(
            campaignCode: trimmedCode,
            campaign: nil,
            instanceId: instanceId,
            journeyId: journeyId,
            nodeCode: nodeCode,
            source: .publicShow,
            receivedAt: Date(),
            syncResolution: .notSynced,
            completion: completion
        ))
    }

    func trackScreen(_ screen: String) {
        let normalized = screen.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        lastScreen = normalized
        evaluateTrigger(InappMessageTriggerRequest(trigger: .urlMatch, value: normalized))
        evaluateTrigger(InappMessageTriggerRequest(trigger: .urlMatch, value: "screen://\(normalized)"))
    }

    func trackURL(_ url: String) {
        let normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        lastURL = normalized
        evaluateTrigger(InappMessageTriggerRequest(trigger: .urlMatch, value: normalized))
    }

    func trigger(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        evaluateTrigger(InappMessageTriggerRequest(trigger: .bridge, value: normalized))
    }

    @discardableResult
    func handleSilentPush(userInfo: [AnyHashable: Any]) -> Bool {
        guard let payload = sanitizedDictionary(userInfo["data"]) ?? sanitizedDictionary(userInfo),
              (payload["type"] as? String) == "inapp_sync" else {
            return false
        }

        let receivedAt = Date()
        stateQueue.async {
            guard self.shouldProcessSilentPushOnStateQueue(payload: payload, now: receivedAt) else {
                return
            }
            self.processSilentPushOnStateQueue(payload: payload, receivedAt: receivedAt)
        }
        return true
    }

    @discardableResult
    func handlePushClick(userInfo: [AnyHashable: Any]) -> Bool {
        guard let code = inAppCode(from: userInfo) else {
            return false
        }

        let rootPayload = sanitizedDictionary(userInfo) ?? [:]
        let nestedPayload = sanitizedDictionary(userInfo["data"]) ?? [:]
        let payloads = [rootPayload, nestedPayload]
        let instanceId = trimmedString(metadataValue(["instanceId", "instance_id"], in: payloads))
        let journeyId = intValue(metadataValue(["journeyId", "journey_id"], in: payloads))
        let nodeCode = trimmedString(metadataValue(["nodeCode", "node_code"], in: payloads))
        enqueueLogicalItem(InappMessageLogicalQueueItem(
            campaignCode: code,
            campaign: nil,
            instanceId: instanceId,
            journeyId: journeyId,
            nodeCode: nodeCode,
            source: .pushClick,
            receivedAt: Date(),
            syncResolution: .notSynced,
            completion: nil
        ))
        return true
    }

    func setActionListener(_ listener: AppBoxInappMessageActionListener?) {
        actionListener = listener
    }

    private func sync(
        evaluateImmediate: Bool,
        forceFull: Bool = false,
        sessionId: Int? = nil,
        completion: ((Bool, Error?) -> Void)?
    ) {
        stateQueue.async {
            guard !self.isSyncing else {
                DispatchQueue.main.async { completion?(false, nil) }
                return
            }
            guard let projectCode = self.currentProjectCode(),
                  let secret = self.makeApiSecret(),
                  !self.currentDeviceUserId().isEmpty else {
                self.markPendingExactRequestsOnStateQueue(resolution: .syncFailed)
                self.drainNextLogicalCandidateOnStateQueue()
                DispatchQueue.main.async { completion?(false, nil) }
                return
            }
            let deviceUserId = self.currentDeviceUserId()
            let appPackageId = self.environment.appPackageId
            let syncVersion = forceFull ? nil : self.syncVersionStore.read(
                projectCode: projectCode,
                appPackageId: appPackageId,
                deviceUserId: deviceUserId
            )

            self.isSyncing = true
            self.syncApi.sync(
                apiDomain: self.environment.apiDomain,
                apiKey: secret.apiKey,
                time: secret.time,
                projectCode: projectCode,
                appPackageId: appPackageId,
                deviceUserId: deviceUserId,
                syncVersion: syncVersion
            ) { result in
                self.stateQueue.async {
                    self.isSyncing = false

                    switch result {
                    case .success(let response):
                        guard response.data.success, let data = response.data.data else {
                            self.clearForegroundRestorePendingSyncOnStateQueue(sessionId: sessionId)
                            self.markPendingExactRequestsOnStateQueue(resolution: .syncFailed)
                            if self.canContinueDisplayAfterSync(sessionId: sessionId) {
                                self.drainNextLogicalCandidateOnStateQueue()
                            }
                            DispatchQueue.main.async { completion?(false, nil) }
                            return
                        }
                        if let syncVersion = data.syncVersion {
                            self.syncVersionStore.save(
                                syncVersion,
                                projectCode: projectCode,
                                appPackageId: appPackageId,
                                deviceUserId: deviceUserId
                            )
                        }
                        self.isServerDisplayGateAllowed = !self.isServerDisplayGateBlocked(syncData: data)
                        guard self.isServerDisplayGateAllowed else {
                            self.clearForegroundRestorePendingSyncOnStateQueue(sessionId: sessionId)
                            self.markPendingExactRequestsOnStateQueue(resolution: .serverGateBlocked)
                            self.clearLogicalQueueOnStateQueue(reason: Self.serverDisplayGateBlockedReason)
                            Task { @MainActor in
                                self.renderer.dismiss(animated: false)
                            }
                            DispatchQueue.main.async { completion?(true, nil) }
                            return
                        }
                        if data.synced == true {
                            self.markPendingExactRequestsAfterSyncOnStateQueue(syncData: data)
                            if self.canContinueDisplayAfterSync(sessionId: sessionId) {
                                self.drainNextLogicalCandidateOnStateQueue()
                            }
                            self.clearForegroundRestorePendingSyncOnStateQueue(sessionId: sessionId)
                            if evaluateImmediate, self.canContinueDisplayAfterSync(sessionId: sessionId) {
                                self.evaluateTrigger(InappMessageTriggerRequest(trigger: .immediate))
                            }
                            DispatchQueue.main.async { completion?(true, nil) }
                            return
                        }
                        self.persist(syncData: data, projectCode: projectCode, deviceUserId: deviceUserId) {
                            self.markPendingExactRequestsAfterSyncOnStateQueue(syncData: data)
                            if self.canContinueDisplayAfterSync(sessionId: sessionId) {
                                self.drainNextLogicalCandidateOnStateQueue()
                            }
                            self.clearForegroundRestorePendingSyncOnStateQueue(sessionId: sessionId)
                            if evaluateImmediate, self.canContinueDisplayAfterSync(sessionId: sessionId) {
                                self.evaluateTrigger(InappMessageTriggerRequest(trigger: .immediate))
                            }
                            DispatchQueue.main.async { completion?(true, nil) }
                        }
                    case .failure(let error):
                        self.clearForegroundRestorePendingSyncOnStateQueue(sessionId: sessionId)
                        self.markPendingExactRequestsOnStateQueue(resolution: .syncFailed)
                        if self.canContinueDisplayAfterSync(sessionId: sessionId) {
                            self.drainNextLogicalCandidateOnStateQueue()
                        }
                        DispatchQueue.main.async { completion?(false, error) }
                    }
                }
            }
        }
    }

    private func enqueueLogicalItem(_ item: InappMessageLogicalQueueItem) {
        stateQueue.async {
            self.enqueueLogicalItemOnStateQueue(item)
        }
    }

    private func enqueueLogicalItemOnStateQueue(_ item: InappMessageLogicalQueueItem) {
        guard isServerDisplayGateAllowed else {
            item.completion?(.skipped(Self.serverDisplayGateBlockedReason))
            return
        }

        guard currentDisplayingCampaignCode != item.campaignCode else {
            item.completion?(.skipped(Self.campaignAlreadyDisplayingReason))
            return
        }

        pendingLogicalQueue.updateOrAppend(item)
        drainNextLogicalCandidateOnStateQueue()
    }

    private func drainNextLogicalCandidateOnStateQueue() {
        guard canDisplayOnStateQueue else { return }
        guard !isDrainingLogicalQueue, !isDisplayingLogicalItem else { return }

        guard let projectCode = currentProjectCode() else {
            clearLogicalQueueOnStateQueue(reason: "project_id_unavailable")
            return
        }

        isDrainingLogicalQueue = true
        while let item = pendingLogicalQueue.first {
            if item.isExactRequest, item.syncResolution == .notSynced {
                guard !isSyncing else {
                    isDrainingLogicalQueue = false
                    return
                }
                let sessionId = displaySessionId
                isDrainingLogicalQueue = false
                sync(evaluateImmediate: false, forceFull: false, sessionId: sessionId, completion: nil)
                return
            }

            if let reason = skipReason(for: item.syncResolution) {
                pendingLogicalQueue.poll()
                item.completion?(.skipped(reason))
                continue
            }

            pendingLogicalQueue.poll()
            let storedCampaign = item.campaign ?? campaignRepository.fetchCampaign(
                projectCode: projectCode,
                campaignCode: item.campaignCode
            )
            let usesFallbackCampaign = storedCampaign == nil && item.syncResolution == .syncedNoChangeFallbackAllowed
            guard let campaign = storedCampaign ?? (usesFallbackCampaign ? fallbackCampaign(projectCode: projectCode, campaignCode: item.campaignCode) : nil) else {
                item.completion?(.skipped("campaign_metadata_missing"))
                continue
            }

            guard isDisplayable(campaign, now: Date(), checksFrequency: !usesFallbackCampaign) else {
                item.completion?(.skipped("campaign_not_displayable"))
                continue
            }

            let sessionId = displaySessionId
            isDisplayingLogicalItem = true
            currentDisplayingCampaignCode = campaign.campaignCode
            isDrainingLogicalQueue = false
            show(
                campaign: campaign,
                instanceId: item.instanceId,
                journeyId: item.journeyId,
                nodeCode: item.nodeCode,
                recordsFrequency: !usesFallbackCampaign,
                completion: { [weak self] result in
                    guard let self else { return }
                    self.stateQueue.async {
                        guard self.displaySessionId == sessionId else {
                            self.isDisplayingLogicalItem = false
                            self.currentDisplayingCampaignCode = nil
                            item.completion?(.skipped("display_session_inactive"))
                            return
                        }
                        switch result {
                        case .shown, .queued:
                            item.completion?(result)
                        case .skipped, .failed:
                            self.isDisplayingLogicalItem = false
                            self.currentDisplayingCampaignCode = nil
                            item.completion?(result)
                            self.drainNextLogicalCandidateOnStateQueue()
                        }
                    }
                },
                sessionId: sessionId
            )
            return
        }

        isDrainingLogicalQueue = false
    }

    private func skipReason(for resolution: ExactSyncResolution) -> String? {
        switch resolution {
        case .notSynced, .metadataResolved, .syncedNoChangeFallbackAllowed:
            return nil
        case .fullListMissing:
            return "full_list_missing"
        case .serverGateBlocked:
            return Self.serverDisplayGateBlockedReason
        case .syncFailed:
            return "sync_failed"
        }
    }

    private func markPendingExactRequestsAfterSyncOnStateQueue(syncData: InappMessageSyncData) {
        let fullListCampaignCodes = Set(syncData.campaigns.map(\.campaignCode))
        pendingLogicalQueue.updateExactRequests { item in
            if syncData.synced == true {
                item.syncResolution = .syncedNoChangeFallbackAllowed
            } else if fullListCampaignCodes.contains(item.campaignCode) {
                item.syncResolution = .metadataResolved
            } else {
                item.syncResolution = .fullListMissing
            }
        }
    }

    private func markPendingExactRequestsOnStateQueue(resolution: ExactSyncResolution) {
        pendingLogicalQueue.updateExactRequests { item in
            item.syncResolution = resolution
        }
    }

    private func persist(
        syncData: InappMessageSyncData,
        projectCode: String,
        deviceUserId: String,
        completion: @escaping () -> Void
    ) {
        let campaigns = syncData.campaigns.enumerated().map { index, campaign in
            normalized(campaign.withDisplayOrder(index), projectCode: projectCode)
        }
        let contents = syncData.contents.compactMap { normalized($0, projectCode: projectCode, campaignCode: $0.campaignCode) }
        let keepCampaignCodes = Set(syncData.campaigns.map(\.campaignCode).filter { !$0.isEmpty })
        let allowsCleanup = InappMessageStaleCachePolicy.allowsCleanup(
            syncData: syncData,
            deviceUserId: deviceUserId
        )
        let group = DispatchGroup()

        group.enter()
        campaignRepository.upsert(campaigns: campaigns) {
            group.leave()
        }

        for content in contents {
            group.enter()
            contentRepository.upsert(content: content) {
                group.leave()
            }
        }

        group.notify(queue: stateQueue) {
            guard allowsCleanup else {
                completion()
                return
            }

            self.campaignRepository.deleteMissing(
                projectCode: projectCode,
                keeping: keepCampaignCodes
            ) { deletedCampaignCodes in
                self.contentRepository.delete(
                    projectCode: projectCode,
                    campaignCodes: Set(deletedCampaignCodes)
                ) {
                    self.stateQueue.async {
                        completion()
                    }
                }
            }
        }
    }

    private func evaluateTrigger(_ request: InappMessageTriggerRequest) {
        stateQueue.async {
            self.evaluateTriggerOnStateQueue(request)
        }
    }

    private func evaluateTriggerOnStateQueue(_ request: InappMessageTriggerRequest) {
        guard request.trigger == .immediate else { return }
        guard canDisplayOnStateQueue else { return }
        guard let projectCode = currentProjectCode() else { return }
        let now = Date()
        let campaigns = campaignRepository.fetchDisplayableCampaigns(projectCode: projectCode, now: Date())
        let matches = triggerEngine.selectCampaigns(from: campaigns, request: request)
            .filter { $0.campaign.campaignCode != currentDisplayingCampaignCode }
            .filter { isDisplayable($0.campaign, now: now, checksFrequency: true) }
        guard !matches.isEmpty else {
            return
        }

        pendingLogicalQueue.enqueue(matches.map { match in
            InappMessageLogicalQueueItem(
                campaignCode: match.campaign.campaignCode,
                campaign: match.campaign,
                instanceId: nil,
                journeyId: match.journeyId,
                nodeCode: match.nodeCode,
                source: .immediate,
                receivedAt: Date(),
                syncResolution: .metadataResolved,
                completion: nil
            )
        })
        drainNextLogicalCandidateOnStateQueue()
    }

    private func handleQueuedMessageDismissed(_ reason: InappMessagePresentationDismissReason) {
        stateQueue.async {
            guard self.isDisplayingLogicalItem else { return }
            self.isDisplayingLogicalItem = false
            self.currentDisplayingCampaignCode = nil
            switch reason {
            case .user:
                self.drainNextLogicalCandidateOnStateQueue()
            case .lifecycle, .programmatic:
                self.clearLogicalQueueOnStateQueue(reason: "presentation_dismissed")
            }
        }
    }

    private func clearLogicalQueueOnStateQueue(reason: String) {
        let removed = pendingLogicalQueue.clear()
        removed.forEach { $0.completion?(.skipped(reason)) }
        isDrainingLogicalQueue = false
        isDisplayingLogicalItem = false
        currentDisplayingCampaignCode = nil
    }

    private func activateDisplaySessionOnStateQueue(sessionId: Int) {
        guard isDisplayScreenActive, displaySessionId == sessionId else { return }
        pendingDisplayActivation = nil
        pendingDisplayActivationDelay = nil
        isDisplayScreenReady = true
        drainNextLogicalCandidateOnStateQueue()
        guard foregroundRestorePendingSyncSessionId != sessionId else { return }
        evaluateTriggerOnStateQueue(InappMessageTriggerRequest(trigger: .immediate))
    }

    private func endDisplaySessionOnStateQueue() {
        pendingDisplayActivation?.cancel()
        pendingDisplayActivation = nil
        pendingDisplayActivationDelay = nil
        foregroundRestorePendingSyncSessionId = nil
        displaySessionId &+= 1
        isDisplayScreenActive = false
        isDisplayScreenReady = false
        isDisplayingLogicalItem = false
        currentDisplayingCampaignCode = nil
    }

    private func captureDisplaySessionForBackgroundRestoreOnStateQueue() {
        restoreDisplaySessionAfterBackground = isDisplayScreenActive
        restoreDisplaySessionWasReady = isDisplayScreenReady
        restoreDisplayDelayAfterBackground = isDisplayScreenActive && !isDisplayScreenReady
            ? pendingDisplayActivationDelay
            : nil
    }

    private func restoreDisplaySessionAfterBackgroundOnStateQueue() -> Int? {
        guard restoreDisplaySessionAfterBackground else {
            clearBackgroundRestoreStateOnStateQueue()
            return nil
        }

        let wasReady = restoreDisplaySessionWasReady
        let restoreDelay = restoreDisplayDelayAfterBackground
        clearBackgroundRestoreStateOnStateQueue()

        pendingDisplayActivation?.cancel()
        pendingDisplayActivation = nil
        pendingDisplayActivationDelay = nil
        displaySessionId &+= 1
        let sessionId = displaySessionId
        isDisplayScreenActive = true
        isDisplayScreenReady = false
        isDisplayingLogicalItem = false
        currentDisplayingCampaignCode = nil

        if wasReady || restoreDelay == nil {
            isDisplayScreenReady = true
            drainNextLogicalCandidateOnStateQueue()
            return sessionId
        }

        if let restoreDelay {
            pendingDisplayActivationDelay = restoreDelay
            pendingDisplayActivation = scheduler.schedule(after: restoreDelay) { [weak self] in
                self?.stateQueue.async {
                    self?.activateDisplaySessionOnStateQueue(sessionId: sessionId)
                }
            }
        }

        return sessionId
    }

    private func clearBackgroundRestoreStateOnStateQueue() {
        restoreDisplaySessionAfterBackground = false
        restoreDisplaySessionWasReady = false
        restoreDisplayDelayAfterBackground = nil
    }

    private func clearForegroundRestorePendingSyncOnStateQueue(sessionId: Int?) {
        guard let sessionId,
              foregroundRestorePendingSyncSessionId == sessionId else {
            return
        }
        foregroundRestorePendingSyncSessionId = nil
    }

    private var canDisplayOnStateQueue: Bool {
        isDisplayScreenActive && isDisplayScreenReady && isServerDisplayGateAllowed
    }

    private func isDisplaySessionValidOnStateQueue(_ sessionId: Int) -> Bool {
        canDisplayOnStateQueue && displaySessionId == sessionId
    }

    private func validateDisplaySession(
        _ sessionId: Int,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        stateQueue.async {
            let isValid = self.isDisplaySessionValidOnStateQueue(sessionId)
            Task { @MainActor in
                completion(isValid)
            }
        }
    }

    private func canContinueDisplayAfterSync(sessionId: Int?) -> Bool {
        guard canDisplayOnStateQueue else { return false }
        guard let sessionId else { return true }
        return displaySessionId == sessionId
    }

    private static func normalizedDisplayDelay(_ delay: TimeInterval) -> TimeInterval {
        guard delay.isFinite, delay > 0 else { return 0 }
        return min(delay, maxDisplayDelay)
    }

    private func isServerDisplayGateBlocked(syncData: InappMessageSyncData) -> Bool {
        syncData.subscribe == false || syncData.mauExceeded == true
    }

    private func fallbackCampaign(projectCode: String, campaignCode: String) -> InappMessageCampaign {
        InappMessageCampaign(
            projectCode: projectCode,
            campaignCode: campaignCode,
            status: .active,
            trigger: .immediate,
            renderFormat: .spec,
            hasSpec: true
        )
    }

    private func show(
        campaign: InappMessageCampaign,
        instanceId: String?,
        journeyId: Int?,
        nodeCode: String?,
        recordsFrequency: Bool,
        completion: ((InappMessageNativeServiceResult) -> Void)?,
        sessionId: Int
    ) {
        guard isDisplaySessionValidOnStateQueue(sessionId) else {
            completion?(.skipped("display_session_inactive"))
            return
        }

        let cachedContent = contentRepository.fetchContent(
            projectCode: campaign.projectCode,
            campaignCode: campaign.campaignCode
        )

        if let cachedContent, !isNativeRenderable(cachedContent) {
            inappDebugLog(
                "InappMessageNativeService: cached content skipped campaignCode=\(campaign.campaignCode), reason=\(nativeSkipReason(for: cachedContent))"
            )
        }

        if !isNativeRenderableCampaign(campaign) {
            let reason = nativeSkipReason(for: campaign)
            inappDebugLog("InappMessageNativeService: campaign skipped campaignCode=\(campaign.campaignCode), reason=\(reason)")
            completion?(.skipped(reason))
            return
        }

        fetchContentAndShow(
            campaign: campaign,
            cachedContent: cachedContent,
            instanceId: instanceId,
            journeyId: journeyId,
            nodeCode: nodeCode,
            recordsFrequency: recordsFrequency,
            completion: completion,
            sessionId: sessionId
        )
    }

    private func fetchContentAndShow(
        campaign: InappMessageCampaign,
        cachedContent: InappMessageContent?,
        instanceId: String?,
        journeyId: Int?,
        nodeCode: String?,
        recordsFrequency: Bool,
        completion: ((InappMessageNativeServiceResult) -> Void)?,
        sessionId: Int
    ) {
        guard isDisplaySessionValidOnStateQueue(sessionId) else {
            completion?(.skipped("display_session_inactive"))
            return
        }
        guard let secret = makeApiSecret() else {
            completion?(.failed("api_secret_unavailable"))
            return
        }

        contentApi.fetchContent(
            apiDomain: environment.apiDomain,
            apiKey: secret.apiKey,
            time: secret.time,
            projectCode: campaign.projectCode,
            campaignCode: campaign.campaignCode,
            appPackageId: environment.appPackageId,
            deviceUserId: currentDeviceUserId(),
            etag: cachedContent?.etag,
            lastModified: cachedContent?.lastModified
        ) { [weak self] result in
            guard let self else { return }
            self.stateQueue.async {
                guard self.isDisplaySessionValidOnStateQueue(sessionId) else {
                    DispatchQueue.main.async { completion?(.skipped("display_session_inactive")) }
                    return
                }

                switch result {
                case .success(let response):
                    if response.statusCode == 304 {
                        if !self.presentCachedContentIfPossible(
                            cachedContent,
                            campaign: campaign,
                            instanceId: instanceId,
                            journeyId: journeyId,
                            nodeCode: nodeCode,
                            recordsFrequency: recordsFrequency,
                            completion: completion,
                            sessionId: sessionId
                        ) {
                            DispatchQueue.main.async { completion?(.skipped("content_unavailable")) }
                        }
                        return
                    }

                    guard response.data.success else {
                        DispatchQueue.main.async { completion?(.skipped("content_unavailable")) }
                        return
                    }

                    guard let rawContent = response.data.data else {
                        let reason = response.data.nativeSkipReason ?? "content_unavailable"
                        inappDebugLog(
                            "InappMessageNativeService: content skipped campaignCode=\(campaign.campaignCode), reason=\(reason)"
                        )
                        DispatchQueue.main.async { completion?(.skipped(reason)) }
                        return
                    }

                    guard let content = self.normalized(
                        rawContent,
                        projectCode: campaign.projectCode,
                        campaignCode: campaign.campaignCode
                    ), let spec = content.spec else {
                        let reason = self.nativeSkipReason(for: rawContent)
                        inappDebugLog(
                            "InappMessageNativeService: content skipped campaignCode=\(campaign.campaignCode), reason=\(reason)"
                        )
                        DispatchQueue.main.async { completion?(.skipped(reason)) }
                        return
                    }

                    self.contentRepository.upsert(content: content) {
                        self.stateQueue.async {
                            guard self.isDisplaySessionValidOnStateQueue(sessionId) else {
                                DispatchQueue.main.async { completion?(.skipped("display_session_inactive")) }
                                return
                            }
                            self.present(
                                spec: spec,
                                campaign: campaign,
                                instanceId: instanceId,
                                journeyId: journeyId,
                                nodeCode: nodeCode,
                                recordsFrequency: recordsFrequency,
                                completion: completion,
                                sessionId: sessionId
                            )
                        }
                    }
                case .failure(let error):
                    if self.presentCachedContentIfPossible(
                        cachedContent,
                        campaign: campaign,
                        instanceId: instanceId,
                        journeyId: journeyId,
                        nodeCode: nodeCode,
                        recordsFrequency: recordsFrequency,
                        completion: completion,
                        sessionId: sessionId
                    ) {
                        return
                    }
                    DispatchQueue.main.async { completion?(.failed(error.localizedDescription)) }
                }
            }
        }
    }

    @discardableResult
    private func presentCachedContentIfPossible(
        _ cachedContent: InappMessageContent?,
        campaign: InappMessageCampaign,
        instanceId: String?,
        journeyId: Int?,
        nodeCode: String?,
        recordsFrequency: Bool,
        completion: ((InappMessageNativeServiceResult) -> Void)?,
        sessionId: Int
    ) -> Bool {
        guard isDisplaySessionValidOnStateQueue(sessionId) else {
            return false
        }
        guard let cachedContent, let spec = cachedContent.spec, isNativeRenderable(cachedContent) else {
            return false
        }
        present(
            spec: spec,
            campaign: campaign,
            instanceId: instanceId,
            journeyId: journeyId,
            nodeCode: nodeCode,
            recordsFrequency: recordsFrequency,
            completion: completion,
            sessionId: sessionId
        )
        return true
    }

    private func present(
        spec: InappMessageRenderSpec,
        campaign: InappMessageCampaign,
        instanceId: String?,
        journeyId: Int?,
        nodeCode: String?,
        recordsFrequency: Bool,
        completion: ((InappMessageNativeServiceResult) -> Void)?,
        sessionId: Int
    ) {
        let context = InappMessageEventContext(
            campaignCode: campaign.campaignCode,
            appProjectCode: campaign.projectCode,
            deviceUserId: currentDeviceUserId(),
            instanceId: instanceId,
            journeyId: journeyId,
            nodeCode: nodeCode
        )
        let options = InappMessageLocalRendererOptions(
            presentationIdentifier: campaign.campaignCode,
            preferredScene: nil,
            openLinks: true,
            debugGuidesEnabled: false,
            eventContext: context,
            eventReporter: eventReporter,
            onEvent: { [weak self] event in
                guard recordsFrequency, event.type == .impression else { return }
                self?.impressionRepository.recordImpression(campaignCode: campaign.campaignCode, now: Date())
            },
            onDismissToday: { [weak self] _ in
                self?.impressionRepository.setDontShowToday(campaignCode: campaign.campaignCode, now: Date())
            },
            onEventAction: { [weak self] action, actionValue in
                // dispatcher는 캠페인을 모른다. campaignCode는 이 계층에서만 알 수 있어 여기서 결합한다.
                self?.actionListener?(
                    AppBoxInappMessageActionInfo(
                        campaignCode: campaign.campaignCode,
                        action: action,
                        actionValue: actionValue
                    )
                )
            },
            onDismissed: { [weak self] reason in
                self?.handleQueuedMessageDismissed(reason)
            }
        )

        validateDisplaySession(sessionId) { [weak self] isValid in
            guard let self else { return }
            guard isValid else {
                completion?(.skipped("display_session_inactive"))
                return
            }
            guard let presenter = self.environment.currentPresenter() else {
                completion?(.skipped("presenter_unavailable"))
                return
            }

            self.renderer.show(spec: spec, from: presenter, options: options) { result in
                self.validateDisplaySession(sessionId) { isValid in
                    guard isValid else {
                        completion?(.skipped("display_session_inactive"))
                        return
                    }
                    self.completePresentation(result, completion: completion)
                }
            }
        }
    }

    private func completePresentation(
        _ result: Result<Void, Error>,
        completion: ((InappMessageNativeServiceResult) -> Void)?
    ) {
        switch result {
        case .success:
            completion?(.shown)
        case .failure(let error):
            completion?(.failed(error.localizedDescription))
        }
    }

    private func isDisplayable(
        _ campaign: InappMessageCampaign,
        now: Date,
        checksFrequency: Bool
    ) -> Bool {
        guard campaign.status == .active,
              campaign.hasSpec,
              campaign.specVersion <= InappMessageRenderSpec.maxSupportedVersion,
              isNativeRenderableCampaign(campaign),
              (campaign.startAt.map { $0 <= now } ?? true),
              (campaign.endAt.map { $0 >= now } ?? true) else {
            return false
        }

        guard checksFrequency else { return true }
        return impressionRepository.isAllowedToShow(
            campaignCode: campaign.campaignCode,
            frequencyType: campaign.frequency.rawValue,
            limit: campaign.frequencyLimit,
            now: now
        )
    }

    private func isJourneyContext(
        instanceId: String?,
        journeyId: Int?,
        nodeCode: String?,
        trigger: InappMessageTrigger? = nil
    ) -> Bool {
        trigger == .journeyPush || instanceId != nil || journeyId != nil || nodeCode != nil
    }

    private func normalized(_ campaign: InappMessageCampaign, projectCode: String) -> InappMessageCampaign {
        InappMessageCampaign(
            projectCode: campaign.projectCode.isEmpty ? projectCode : campaign.projectCode,
            campaignCode: campaign.campaignCode,
            status: campaign.status,
            trigger: campaign.trigger,
            triggerValue: campaign.triggerValue,
            priority: campaign.priority,
            displayOrder: campaign.displayOrder,
            frequency: campaign.frequency,
            frequencyLimit: campaign.frequencyLimit,
            startAt: campaign.startAt,
            endAt: campaign.endAt,
            renderFormat: campaign.renderFormat,
            specVersion: campaign.specVersion,
            hasSpec: campaign.hasSpec,
            targetingJson: campaign.targetingJson,
            conversionsJson: campaign.conversionsJson,
            journeyJson: campaign.journeyJson,
            rawMetaJson: campaign.rawMetaJson,
            syncedAt: campaign.syncedAt
        )
    }

    private func normalized(
        _ content: InappMessageContent,
        projectCode: String,
        campaignCode: String
    ) -> InappMessageContent? {
        guard isNativeRenderable(content) else { return nil }
        return InappMessageContent(
            projectCode: content.projectCode.isEmpty ? projectCode : content.projectCode,
            campaignCode: content.campaignCode.isEmpty ? campaignCode : content.campaignCode,
            renderFormat: content.renderFormat,
            specVersion: content.specVersion,
            spec: content.spec,
            specJson: content.specJson,
            etag: content.etag,
            lastModified: content.lastModified,
            fetchedAt: content.fetchedAt,
            expiresAt: content.expiresAt,
            contentHash: content.contentHash
        )
    }

    private func isNativeRenderable(_ content: InappMessageContent) -> Bool {
        nativeSkipReason(for: content) == "native_renderable"
    }

    private func isNativeRenderableCampaign(_ campaign: InappMessageCampaign) -> Bool {
        campaign.renderFormat == .spec || campaign.renderFormat == .dual
    }

    private func nativeSkipReason(for campaign: InappMessageCampaign) -> String {
        if campaign.renderFormat == .html {
            return "html_render_format"
        }
        if campaign.renderFormat != .spec && campaign.renderFormat != .dual {
            return "unsupported_render_format"
        }
        if campaign.specVersion > InappMessageRenderSpec.maxSupportedVersion {
            return "unsupported_spec_version"
        }
        if !campaign.hasSpec {
            return "missing_native_spec"
        }
        return "native_renderable"
    }

    private func nativeSkipReason(for content: InappMessageContent) -> String {
        if content.renderFormat == .html {
            return "html_render_format"
        }
        if content.renderFormat != .spec && content.renderFormat != .dual {
            return "unsupported_render_format"
        }
        if content.specVersion > InappMessageRenderSpec.maxSupportedVersion {
            return "unsupported_spec_version"
        }
        guard let spec = content.spec else {
            return "missing_native_spec"
        }
        if spec.specVersion > InappMessageRenderSpec.maxSupportedVersion {
            return "unsupported_spec_version"
        }
        return "native_renderable"
    }

    private func currentProjectCode() -> String? {
        environment.currentProjectCode()
    }

    private func currentDeviceUserId() -> String {
        environment.currentDeviceUserId()
    }

    private func makeApiSecret() -> (apiKey: Data, time: String)? {
        environment.makeApiSecret()
    }

    private func inAppCode(from userInfo: [AnyHashable: Any]) -> String? {
        [userInfo["param"], userInfo["link"], userInfo["code"], userInfo["campaignCode"]]
            .compactMap(trimmedString)
            .compactMap(extractInAppCode)
            .first
    }

    private func extractInAppCode(from value: String) -> String? {
        if value.hasPrefix("INAPP-") {
            return value
        }

        guard let range = value.range(
            of: #"INAPP-[A-Za-z0-9_-]+"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }

        return String(value[range])
    }

    private func trimmedString(_ value: Any?) -> String? {
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

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private func isRequestShowOnlySilentPush(payload: [String: Any]) -> Bool {
        let triggerType = trimmedString(metadataValue(["triggerType", "trigger_type", "trigger"], in: [payload]))?
            .uppercased()
            .replacingOccurrences(of: "-", with: "_")
        return triggerType == "URL_MATCH" || triggerType == "BRIDGE"
    }

    private func shouldDirectDisplaySilentPush(
        payload: [String: Any],
        instanceId: String?,
        journeyId: Int?,
        nodeCode: String?
    ) -> Bool {
        let triggerType = trimmedString(metadataValue(["triggerType", "trigger_type", "trigger"], in: [payload]))?
            .uppercased()
        if triggerType == InappMessageTrigger.immediate.rawValue {
            return false
        }
        return instanceId != nil || journeyId != nil || nodeCode != nil
    }

    private func metadataValue(_ keys: [String], in payloads: [[String: Any]]) -> Any? {
        for payload in payloads {
            for key in keys {
                if let value = payload[key] {
                    return value
                }
            }
        }
        return nil
    }

    private func processSilentPushOnStateQueue(payload: [String: Any], receivedAt: Date) {
        let instanceId = trimmedString(metadataValue(["instanceId", "instance_id"], in: [payload]))
        let journeyId = intValue(metadataValue(["journeyId", "journey_id"], in: [payload]))
        let nodeCode = trimmedString(metadataValue(["nodeCode", "node_code"], in: [payload]))

        if isRequestShowOnlySilentPush(payload: payload) {
            sync(evaluateImmediate: false, completion: nil)
            return
        }

        if let code = trimmedString(metadataValue(["campaignCode", "campaign_code", "code"], in: [payload])) {
            enqueueLogicalItemOnStateQueue(InappMessageLogicalQueueItem(
                campaignCode: code,
                campaign: nil,
                instanceId: instanceId,
                journeyId: journeyId,
                nodeCode: nodeCode,
                source: .silentPush,
                receivedAt: receivedAt,
                syncResolution: .notSynced,
                completion: nil
            ))
        } else {
            sync(evaluateImmediate: true, completion: nil)
        }
    }

    private func shouldProcessSilentPushOnStateQueue(payload: [String: Any], now: Date) -> Bool {
        let signature = silentPushSignature(payload)
        if lastSilentPushSignature == signature,
           let lastSilentPushAt,
           now.timeIntervalSince(lastSilentPushAt) < Self.silentPushDedupeWindow {
            return false
        }
        lastSilentPushSignature = signature
        lastSilentPushAt = now
        return true
    }

    private func silentPushSignature(_ payload: [String: Any]) -> String {
        payload.keys.sorted().map { key in
            "\(key)=\(String(describing: payload[key] ?? ""))"
        }.joined(separator: "&")
    }

    private func sanitizedDictionary(_ value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        guard let dictionary = value as? [AnyHashable: Any] else {
            return nil
        }
        var result = [String: Any]()
        for (key, value) in dictionary {
            guard let key = key as? String else { continue }
            result[key] = value
        }
        return result
    }
}

struct InappMessageStaleCachePolicy {
    static func allowsCleanup(syncData: InappMessageSyncData, deviceUserId: String) -> Bool {
        let normalizedDeviceUserId = deviceUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        return syncData.synced == false
            && syncData.subscribe != false
            && syncData.mauExceeded != true
            && !normalizedDeviceUserId.isEmpty
    }
}

extension InappMessageNativeService: InappMessageNativeServing, AppBoxInappMessagePushHandling {}
