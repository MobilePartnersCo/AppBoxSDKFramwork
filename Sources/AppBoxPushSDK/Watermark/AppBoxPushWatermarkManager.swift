//
//  AppBoxPushWatermarkManager.swift
//  AppBoxPushSDK
//

import Foundation
@_spi(AppBoxInternal) @_spi(AppBoxPushSDK) import AppBoxCoreSDK

protocol AppBoxPushWatermarkStatusFetching {
    func fetchWatermarkStatus(
        projectId: String,
        context: AppBoxPushWatermarkRequestContext,
        completion: @escaping (Bool) -> Void
    )
}

protocol AppBoxPushWatermarkPresenting: AnyObject {
    func showWatermark()
    func hideWatermark()
}

final class AppBoxPushWatermarkStatusService: AppBoxPushWatermarkStatusFetching {
    private let coreApi: CoreWatermarkApi

    init(coreApi: CoreWatermarkApi = CoreWatermarkApi()) {
        self.coreApi = coreApi
    }

    func fetchWatermarkStatus(
        projectId: String,
        context: AppBoxPushWatermarkRequestContext,
        completion: @escaping (Bool) -> Void
    ) {
        coreApi.fetchWatermarkStatus(
            apiDomain: context.apiDomain,
            apiKey: context.apiKey,
            time: context.time,
            projectId: projectId,
            completion: completion
        )
    }
}

final class AppBoxPushWatermarkManager {
    static let shared = AppBoxPushWatermarkManager()

    private let fetcher: AppBoxPushWatermarkStatusFetching
    private weak var presenter: AppBoxPushWatermarkPresenting?
    private let stateQueue = DispatchQueue(label: "com.appbox.push.watermark.manager")
    private var inFlightProjectId: String?
    private var resolvedProjectId: String?
    private var currentProjectId: String?

    init(
        fetcher: AppBoxPushWatermarkStatusFetching = AppBoxPushWatermarkStatusService(),
        presenter: AppBoxPushWatermarkPresenting = AppBoxPushWatermarkOverlayPresenter.shared
    ) {
        self.fetcher = fetcher
        self.presenter = presenter
    }

    func bootstrap(projectId: String?, contextProvider: AppBoxPushWatermarkContextProviding?) {
        let trimmedProjectId = projectId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedProjectId.isEmpty else {
            resetAndHide()
            return
        }

        guard let context = contextProvider?.makeWatermarkRequestContext() else {
            resetAndHide()
            return
        }

        let shouldFetch = stateQueue.sync { () -> Bool in
            if trimmedProjectId == inFlightProjectId || trimmedProjectId == resolvedProjectId {
                return false
            }

            currentProjectId = trimmedProjectId
            inFlightProjectId = trimmedProjectId
            return true
        }

        guard shouldFetch else { return }

        fetcher.fetchWatermarkStatus(projectId: trimmedProjectId, context: context) { [weak self] isVisible in
            self?.completeFetch(projectId: trimmedProjectId, isVisible: isVisible)
        }
    }

    private func completeFetch(projectId: String, isVisible: Bool) {
        let shouldApply = stateQueue.sync { () -> Bool in
            guard inFlightProjectId == projectId, currentProjectId == projectId else {
                return false
            }

            inFlightProjectId = nil
            resolvedProjectId = projectId
            return true
        }

        guard shouldApply else { return }

        DispatchQueue.main.async { [weak presenter] in
            if isVisible {
                presenter?.showWatermark()
            } else {
                presenter?.hideWatermark()
            }
        }
    }

    private func resetAndHide() {
        stateQueue.sync {
            currentProjectId = nil
            inFlightProjectId = nil
            resolvedProjectId = nil
        }

        hideOnMain()
    }

    private func hideOnMain() {
        DispatchQueue.main.async { [weak presenter] in
            presenter?.hideWatermark()
        }
    }
}
