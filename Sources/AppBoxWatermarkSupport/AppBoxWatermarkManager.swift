import Foundation
import UIKit
@_spi(AppBoxInternal) import AppBoxCoreSDK

@_spi(AppBoxInternal)
public enum AppBoxWatermarkOwner: String, Hashable {
    case push
    case inappMessage
}

protocol AppBoxWatermarkStatusFetching {
    func fetchWatermarkStatus(
        projectId: String,
        context: AppBoxWatermarkRequestContext,
        completion: @escaping (Result<Bool, CoreWatermarkStatusError>) -> Void
    )
}

protocol AppBoxWatermarkPresenting: AnyObject {
    func showWatermark()
    func hideWatermark()
}

protocol AppBoxWatermarkRetryScheduling: AnyObject {
    @discardableResult
    func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) -> AppBoxWatermarkCancellation
}

protocol AppBoxWatermarkCancellation: AnyObject {
    func cancel()
}

private final class AppBoxWatermarkStatusService: AppBoxWatermarkStatusFetching {
    private let coreApi: CoreWatermarkApi

    init(coreApi: CoreWatermarkApi = CoreWatermarkApi()) {
        self.coreApi = coreApi
    }

    func fetchWatermarkStatus(
        projectId: String,
        context: AppBoxWatermarkRequestContext,
        completion: @escaping (Result<Bool, CoreWatermarkStatusError>) -> Void
    ) {
        coreApi.fetchWatermarkStatusResult(
            apiDomain: context.apiDomain,
            apiKey: context.apiKey,
            time: context.time,
            projectId: projectId,
            completion: completion
        )
    }
}

private final class AppBoxWatermarkDispatchCancellation: AppBoxWatermarkCancellation {
    private let item: DispatchWorkItem
    init(item: DispatchWorkItem) { self.item = item }
    func cancel() { item.cancel() }
}

private final class AppBoxWatermarkDispatchScheduler: AppBoxWatermarkRetryScheduling {
    func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) -> AppBoxWatermarkCancellation {
        let item = DispatchWorkItem(block: block)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return AppBoxWatermarkDispatchCancellation(item: item)
    }
}

@_spi(AppBoxInternal)
public final class AppBoxWatermarkManager {
    public static let shared = AppBoxWatermarkManager()

    private let fetcher: AppBoxWatermarkStatusFetching
    private let presenter: AppBoxWatermarkPresenting
    private let scheduler: AppBoxWatermarkRetryScheduling
    private let stateQueue = DispatchQueue(label: "com.appbox.watermark.manager")
    private var owners = [AppBoxWatermarkOwner: String]()
    private var activeProjectId: String?
    private var activeContext: AppBoxWatermarkRequestContext?
    private var generation = 0
    private var isRequestInFlight = false
    private var lastKnownVisibility: Bool?
    private var retryAttempt = 0
    private var retryCancellation: AppBoxWatermarkCancellation?
    private var retryToken: UUID?
    private var lifecycleObserver: NSObjectProtocol?

    public convenience init() {
        self.init(
            fetcher: AppBoxWatermarkStatusService(),
            presenter: AppBoxWatermarkOverlayPresenter.shared,
            scheduler: AppBoxWatermarkDispatchScheduler()
        )
    }

    init(
        fetcher: AppBoxWatermarkStatusFetching,
        presenter: AppBoxWatermarkPresenting,
        scheduler: AppBoxWatermarkRetryScheduling
    ) {
        self.fetcher = fetcher
        self.presenter = presenter
        self.scheduler = scheduler
        lifecycleObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshOnForeground()
        }
    }

    deinit {
        retryCancellation?.cancel()
        if let lifecycleObserver { NotificationCenter.default.removeObserver(lifecycleObserver) }
    }

    @discardableResult
    public func register(
        owner: AppBoxWatermarkOwner,
        projectId: String?,
        contextProvider: AppBoxWatermarkContextProviding?
    ) -> Bool {
        let projectId = projectId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !projectId.isEmpty, let context = contextProvider?.makeWatermarkRequestContext() else {
            return false
        }

        var shouldFetch = false
        var shouldHide = false
        let accepted = stateQueue.sync { () -> Bool in
            if let activeProjectId {
                if activeProjectId == projectId {
                    owners[owner] = projectId
                    activeContext = context
                    return true
                }

                guard owners[owner] != nil, owners.count == 1 else {
                    return false
                }

                cancelRetryLocked()
                generation += 1
                owners = [owner: projectId]
                self.activeProjectId = projectId
                activeContext = context
                isRequestInFlight = false
                lastKnownVisibility = nil
                retryAttempt = 0
                shouldHide = true
                shouldFetch = true
                return true
            }

            generation += 1
            owners[owner] = projectId
            activeProjectId = projectId
            activeContext = context
            shouldHide = true
            shouldFetch = true
            return true
        }

        guard accepted else {
            debugPrint("[AppBoxWatermarkSupport] rejected project conflict for \(owner.rawValue): \(projectId)")
            return false
        }
        if shouldHide { hideOnMain() }
        if shouldFetch { fetchIfNeeded() }
        return true
    }

    private func fetchIfNeeded() {
        let request = stateQueue.sync { () -> (String, AppBoxWatermarkRequestContext, Int)? in
            guard !isRequestInFlight,
                  retryCancellation == nil,
                  let activeProjectId,
                  let activeContext else { return nil }
            isRequestInFlight = true
            return (activeProjectId, activeContext, generation)
        }
        guard let request else { return }

        fetcher.fetchWatermarkStatus(projectId: request.0, context: request.1) { [weak self] result in
            self?.completeFetch(projectId: request.0, generation: request.2, result: result)
        }
    }

    private func completeFetch(
        projectId: String,
        generation: Int,
        result: Result<Bool, CoreWatermarkStatusError>
    ) {
        var visibilityToApply: Bool?
        stateQueue.sync {
            guard self.generation == generation, activeProjectId == projectId else { return }
            isRequestInFlight = false
            switch result {
            case .success(let isVisible):
                cancelRetryLocked()
                retryAttempt = 0
                lastKnownVisibility = isVisible
                visibilityToApply = isVisible
            case .failure:
                if retryAttempt < Self.retryDelays.count {
                    let retryDelay = Self.retryDelays[retryAttempt]
                    retryAttempt += 1
                    scheduleRetryLocked(after: retryDelay, generation: generation)
                }
            }
        }

        if let visibilityToApply { applyVisibility(visibilityToApply) }
    }

    private func scheduleRetryLocked(after delay: TimeInterval, generation: Int) {
        cancelRetryLocked()
        let token = UUID()
        retryToken = token
        retryCancellation = scheduler.schedule(after: delay) { [weak self] in
            guard let self else { return }
            let shouldFetch = self.stateQueue.sync { () -> Bool in
                guard self.generation == generation, self.retryToken == token else { return false }
                self.retryCancellation = nil
                self.retryToken = nil
                return true
            }
            if shouldFetch { self.fetchIfNeeded() }
        }
    }

    private func cancelRetryLocked() {
        retryCancellation?.cancel()
        retryCancellation = nil
        retryToken = nil
    }

    private func refreshOnForeground() {
        let shouldRetry = stateQueue.sync { () -> Bool in
            guard activeProjectId != nil, !isRequestInFlight else { return false }
            cancelRetryLocked()
            retryAttempt = 0
            return true
        }
        if shouldRetry { fetchIfNeeded() }
    }

    private func applyVisibility(_ isVisible: Bool) {
        DispatchQueue.main.async { [presenter] in
            isVisible ? presenter.showWatermark() : presenter.hideWatermark()
        }
    }

    private func hideOnMain() {
        DispatchQueue.main.async { [presenter] in presenter.hideWatermark() }
    }

    private static let retryDelays: [TimeInterval] = [1, 2, 4]
}
