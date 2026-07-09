import Foundation
import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

struct InappMessageEventContext: Equatable {
    let campaignCode: String
    let appProjectCode: String
    let deviceUserId: String
    let instanceId: String?
    let journeyId: Int?
    let nodeCode: String?

    init(
        campaignCode: String,
        appProjectCode: String,
        deviceUserId: String,
        instanceId: String? = nil,
        journeyId: Int? = nil,
        nodeCode: String? = nil
    ) {
        self.campaignCode = campaignCode
        self.appProjectCode = appProjectCode
        self.deviceUserId = deviceUserId
        self.instanceId = instanceId
        self.journeyId = journeyId
        self.nodeCode = nodeCode
    }
}

enum InappMessageEventReportOutcome: Equatable {
    case skipped
    case sent(Int)
    case queued(Int)
    case dropped(Int)
}

struct InappMessageEventSendResult {
    let statusCode: Int
    let success: Bool
    let code: Int?

    init(statusCode: Int, success: Bool, code: Int? = nil) {
        self.statusCode = statusCode
        self.success = success
        self.code = code
    }
}

protocol InappMessageEventSending {
    func send(
        events: [InappMessageEvent],
        projectCode: String,
        completion: @escaping (Result<InappMessageEventSendResult, Error>) -> Void
    )
}

protocol InappMessageEventQueueing {
    func appendPendingEvent(event: [String: Any], completion: @escaping (Bool) -> Void)
    func getPendingEvents(completion: @escaping ([CorePendingInAppEvent]) -> Void)
    func getDuePendingEvents(now: Date, completion: @escaping ([CorePendingInAppEvent]) -> Void)
    func removePendingEvents(eventIds: [String], completion: @escaping (Bool) -> Void)
    func markPendingEventsForRetry(
        eventIds: [String],
        now: Date,
        retryDelays: [TimeInterval],
        jitterProvider: @escaping (_ retryCount: Int, _ baseDelay: TimeInterval) -> TimeInterval,
        completion: @escaping (Date?) -> Void
    )
}

extension CoreInAppEventQueueRepository: InappMessageEventQueueing {}

final class InappMessageEventAPISender: InappMessageEventSending {
    private let api: CoreInappMessageEventApi
    private let environment: AppBoxInappMessageEnvironmentProviding

    init(
        api: CoreInappMessageEventApi = CoreInappMessageEventApi(),
        environment: AppBoxInappMessageEnvironmentProviding = AppBoxInappMessageEnvironment.shared
    ) {
        self.api = api
        self.environment = environment
    }

    func send(
        events: [InappMessageEvent],
        projectCode: String,
        completion: @escaping (Result<InappMessageEventSendResult, Error>) -> Void
    ) {
        guard let secret = environment.makeApiSecret() else {
            completion(.failure(NSError(
                domain: "AppBoxInappMessageSDK",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "api_secret_unavailable"]
            )))
            return
        }

        api.sendEvents(
            apiDomain: environment.apiDomain,
            apiKey: secret.apiKey,
            time: secret.time,
            projectCode: projectCode,
            events: events
        ) { result in
            switch result {
            case .success(let response):
                completion(.success(InappMessageEventSendResult(
                    statusCode: response.statusCode,
                    success: response.data.success,
                    code: response.data.code
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

final class InappMessageEventReporter {
    static let shared = InappMessageEventReporter(observesAppLifecycle: true)

    private let sender: InappMessageEventSending
    private let queue: InappMessageEventQueueing
    private let callbackQueue: DispatchQueue
    private let nowProvider: () -> Date
    private let retryDelays: [TimeInterval]
    private let retryJitterProvider: (_ retryCount: Int, _ baseDelay: TimeInterval) -> TimeInterval
    private var observer: NSObjectProtocol?

    init(
        sender: InappMessageEventSending = InappMessageEventAPISender(),
        queue: InappMessageEventQueueing = CoreInAppEventQueueRepository(coreDataManager: CoreDataManager.shared),
        callbackQueue: DispatchQueue = .main,
        nowProvider: @escaping () -> Date = { Date() },
        retryDelays: [TimeInterval] = [1, 2, 4, 8, 16],
        retryJitterProvider: @escaping (_ retryCount: Int, _ baseDelay: TimeInterval) -> TimeInterval = InappMessageEventReporter.defaultRetryJitter,
        observesAppLifecycle: Bool = false
    ) {
        self.sender = sender
        self.queue = queue
        self.callbackQueue = callbackQueue
        self.nowProvider = nowProvider
        self.retryDelays = retryDelays
        self.retryJitterProvider = retryJitterProvider

        if observesAppLifecycle {
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.flushPending()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func report(
        renderEvents: [InappMessageRenderEvent],
        context: InappMessageEventContext?,
        completion: ((InappMessageEventReportOutcome) -> Void)? = nil
    ) {
        guard let context else {
            complete(.skipped, completion)
            return
        }

        let events = makeEvents(from: renderEvents, context: context)
        guard !events.isEmpty else {
            complete(.skipped, completion)
            return
        }

        sendOrQueue(events, projectCode: context.appProjectCode, completion: completion)
    }

    func flushPending(completion: ((InappMessageEventReportOutcome) -> Void)? = nil) {
        queue.getDuePendingEvents(now: nowProvider()) { [weak self] pendingEvents in
            guard let self else { return }

            let events = pendingEvents
                .compactMap(Self.decodePendingEvent)
                .sorted { lhs, rhs in
                    if lhs.ts == rhs.ts {
                        return lhs.eventId < rhs.eventId
                    }
                    return lhs.ts < rhs.ts
                }

            let invalidEventIds = pendingEvents
                .filter { Self.decodePendingEvent($0) == nil }
                .map(\.eventId)

            if !invalidEventIds.isEmpty {
                self.queue.removePendingEvents(eventIds: invalidEventIds) { _ in }
            }

            guard !events.isEmpty else {
                self.complete(.skipped, completion)
                return
            }

            self.flush(groups: Dictionary(grouping: events, by: \.appProjectCode), completion: completion)
        }
    }

    private func flush(
        groups: [String: [InappMessageEvent]],
        completion: ((InappMessageEventReportOutcome) -> Void)?
    ) {
        let validGroups = groups.filter { !$0.key.isEmpty && !$0.value.isEmpty }
        guard !validGroups.isEmpty else {
            complete(.skipped, completion)
            return
        }

        let dispatchGroup = DispatchGroup()
        let lock = NSLock()
        var sentCount = 0
        var droppedCount = 0
        var retryCount = 0

        for (projectCode, events) in validGroups {
            dispatchGroup.enter()
            sender.send(events: events, projectCode: projectCode) { [weak self] result in
                guard let self else {
                    dispatchGroup.leave()
                    return
                }

                self.handleRetrySendResult(result, events: events) { outcome in
                    lock.lock()
                    switch outcome {
                    case .sent(let count):
                        sentCount += count
                    case .dropped(let count):
                        droppedCount += count
                    case .queued(let count):
                        retryCount += count
                    case .skipped:
                        break
                    }
                    lock.unlock()
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: callbackQueue) {
            if sentCount > 0 {
                completion?(.sent(sentCount))
            } else if droppedCount > 0 {
                completion?(.dropped(droppedCount))
            } else if retryCount > 0 {
                completion?(.queued(retryCount))
            } else {
                completion?(.skipped)
            }
        }
    }

    private func sendOrQueue(
        _ events: [InappMessageEvent],
        projectCode: String,
        completion: ((InappMessageEventReportOutcome) -> Void)?
    ) {
        sender.send(events: events, projectCode: projectCode) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let sendResult):
                if self.isSuccessful(sendResult) {
                    self.complete(.sent(events.count), completion)
                } else if self.isRetryable(sendResult) {
                    self.queue(events, scheduleRetry: true, completion: completion)
                } else {
                    self.complete(.dropped(events.count), completion)
                }
            case .failure(let error):
                let statusCode = Self.statusCode(from: error)
                if let statusCode, !self.isRetryable(statusCode: statusCode) {
                    self.complete(.dropped(events.count), completion)
                } else {
                    self.queue(events, scheduleRetry: true, completion: completion)
                }
            }
        }
    }

    private func handleRetrySendResult(
        _ result: Result<InappMessageEventSendResult, Error>,
        events: [InappMessageEvent],
        completion: @escaping (InappMessageEventReportOutcome) -> Void
    ) {
        let eventIds = events.map(\.eventId)

        switch result {
        case .success(let sendResult):
            if isSuccessful(sendResult) {
                queue.removePendingEvents(eventIds: eventIds) { _ in
                    completion(.sent(events.count))
                }
            } else if isRetryable(sendResult) {
                queue.markPendingEventsForRetry(
                    eventIds: eventIds,
                    now: nowProvider(),
                    retryDelays: retryDelays,
                    jitterProvider: retryJitterProvider
                ) { _ in
                    completion(.queued(events.count))
                }
            } else {
                queue.removePendingEvents(eventIds: eventIds) { _ in
                    completion(.dropped(events.count))
                }
            }
        case .failure(let error):
            let statusCode = Self.statusCode(from: error)
            if let statusCode, !isRetryable(statusCode: statusCode) {
                queue.removePendingEvents(eventIds: eventIds) { _ in
                    completion(.dropped(events.count))
                }
            } else {
                queue.markPendingEventsForRetry(
                    eventIds: eventIds,
                    now: nowProvider(),
                    retryDelays: retryDelays,
                    jitterProvider: retryJitterProvider
                ) { _ in
                    completion(.queued(events.count))
                }
            }
        }
    }

    private func queue(
        _ events: [InappMessageEvent],
        scheduleRetry: Bool,
        completion: ((InappMessageEventReportOutcome) -> Void)?
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var savedCount = 0
        let eventIds = events.map(\.eventId)

        for event in events {
            guard let payload = Self.eventDictionary(event) else { continue }
            group.enter()
            self.queue.appendPendingEvent(event: payload) { success in
                if success {
                    lock.lock()
                    savedCount += 1
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: callbackQueue) {
            guard scheduleRetry, savedCount > 0 else {
                completion?(.queued(savedCount))
                return
            }

            self.queue.markPendingEventsForRetry(
                eventIds: eventIds,
                now: self.nowProvider(),
                retryDelays: self.retryDelays,
                jitterProvider: self.retryJitterProvider
            ) { _ in
                self.complete(.queued(savedCount), completion)
            }
        }
    }

    private func makeEvents(
        from renderEvents: [InappMessageRenderEvent],
        context: InappMessageEventContext
    ) -> [InappMessageEvent] {
        renderEvents.enumerated().compactMap { index, renderEvent in
            guard let type = renderEvent.type.inappMessageEventType else { return nil }
            let action = renderEvent.action.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = renderEvent.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let component = renderEvent.component.trimmingCharacters(in: .whitespacesAndNewlines)
            let ts = Int64(renderEvent.date.timeIntervalSince1970 * 1000) + Int64(index)

            return InappMessageEvent(
                type: type,
                campaignCode: context.campaignCode,
                component: component.isEmpty ? nil : component,
                action: action.isEmpty ? nil : (InappMessageActionKind(rawValue: action) ?? InappMessageActionKind.none),
                value: value.isEmpty ? nil : value,
                ts: ts,
                appProjectCode: context.appProjectCode,
                deviceUserId: context.deviceUserId,
                instanceId: context.instanceId,
                journeyId: context.journeyId,
                nodeCode: context.nodeCode
            )
        }
    }

    private func isSuccessful(_ result: InappMessageEventSendResult) -> Bool {
        (200...299).contains(result.statusCode) && result.success
    }

    private func isRetryable(_ result: InappMessageEventSendResult) -> Bool {
        if isRetryable(statusCode: result.statusCode) {
            return true
        }

        guard let code = result.code else {
            return false
        }

        return code == 429 || code >= 500
    }

    private func isRetryable(statusCode: Int) -> Bool {
        statusCode == 429 || statusCode >= 500 || statusCode <= 0
    }

    private static func defaultRetryJitter(retryCount: Int, baseDelay: TimeInterval) -> TimeInterval {
        guard baseDelay > 0 else { return 0 }
        return Double.random(in: 0...(baseDelay * 0.2))
    }

    private func complete(
        _ outcome: InappMessageEventReportOutcome,
        _ completion: ((InappMessageEventReportOutcome) -> Void)?
    ) {
        callbackQueue.async {
            completion?(outcome)
        }
    }

    private static func decodePendingEvent(_ event: CorePendingInAppEvent) -> InappMessageEvent? {
        guard let data = event.eventJson.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(InappMessageEvent.self, from: data)
    }

    private static func eventDictionary(_ event: InappMessageEvent) -> [String: Any]? {
        guard
            let data = try? JSONEncoder().encode(event),
            let payload = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            return nil
        }
        return payload
    }

    private static func statusCode(from error: Error) -> Int? {
        let nsError = error as NSError
        if let statusCode = nsError.userInfo["statusCode"] as? Int {
            return statusCode
        }
        return nsError.code > 0 ? nsError.code : nil
    }
}

private extension InappMessageRenderEventType {
    var inappMessageEventType: InappMessageEventType? {
        switch self {
        case .impression:
            return .impression
        case .click:
            return .click
        case .close:
            return .close
        case .conversion:
            return .conversion
        case .dismissToday, .function:
            return nil
        }
    }
}
