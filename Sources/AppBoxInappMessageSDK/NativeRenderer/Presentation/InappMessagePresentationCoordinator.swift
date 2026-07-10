import UIKit

enum InappMessagePresentationResult: Equatable {
    case displayed
    case queued
    case duplicateIgnored
}

enum InappMessagePresentationDismissReason: Equatable {
    case user
    case lifecycle
    case programmatic
}

@MainActor
final class InappMessagePresentationCoordinator {
    static let shared = InappMessagePresentationCoordinator()

    private final class PresentationRequest {
        let identifier: String
        let content: InappMessagePreparedContent
        weak var presenter: UIViewController?
        weak var preferredScene: UIWindowScene?
        let debugGuidesEnabled: Bool
        let actionDispatcher: InappMessageActionDispatcher
        let onDismissed: (InappMessagePresentationDismissReason) -> Void
        var completion: ((Result<InappMessagePresentationResult, Error>) -> Void)?

        init(
            identifier: String,
            content: InappMessagePreparedContent,
            presenter: UIViewController?,
            preferredScene: UIWindowScene?,
            debugGuidesEnabled: Bool,
            actionDispatcher: InappMessageActionDispatcher,
            onDismissed: @escaping (InappMessagePresentationDismissReason) -> Void,
            completion: ((Result<InappMessagePresentationResult, Error>) -> Void)?
        ) {
            self.identifier = identifier
            self.content = content
            self.presenter = presenter
            self.preferredScene = preferredScene
            self.debugGuidesEnabled = debugGuidesEnabled
            self.actionDispatcher = actionDispatcher
            self.onDismissed = onDismissed
            self.completion = completion
        }
    }

    private let overlayWindow: InappMessageOverlayWindow
    private let retryInterval: TimeInterval
    private var showingIdentifier: String?
    private var showingDispatcher: InappMessageActionDispatcher?
    private var showingOnDismissed: ((InappMessagePresentationDismissReason) -> Void)?
    private var currentDismissReason: InappMessagePresentationDismissReason = .programmatic
    private var pendingRequest: PresentationRequest?
    private var pendingRetryWorkItem: DispatchWorkItem?
    private var observers = [NSObjectProtocol]()

    init(
        overlayWindow: InappMessageOverlayWindow = InappMessageOverlayWindow(),
        retryInterval: TimeInterval = 0.35
    ) {
        self.overlayWindow = overlayWindow
        self.retryInterval = retryInterval
        startObservingLifecycleIfNeeded()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        pendingRetryWorkItem?.cancel()
    }

    func show(
        content: InappMessagePreparedContent,
        from presenter: UIViewController?,
        preferredScene: UIWindowScene? = nil,
        identifier: String,
        debugGuidesEnabled: Bool = false,
        actionDispatcher: InappMessageActionDispatcher,
        onDismissed: @escaping (InappMessagePresentationDismissReason) -> Void = { _ in },
        completion: ((Result<InappMessagePresentationResult, Error>) -> Void)? = nil
    ) {
        let normalizedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestIdentifier = normalizedIdentifier.isEmpty ? UUID().uuidString : normalizedIdentifier

        if showingIdentifier == requestIdentifier || pendingRequest?.identifier == requestIdentifier {
            completion?(.success(.duplicateIgnored))
            return
        }

        let request = PresentationRequest(
            identifier: requestIdentifier,
            content: content,
            presenter: presenter,
            preferredScene: preferredScene,
            debugGuidesEnabled: debugGuidesEnabled,
            actionDispatcher: actionDispatcher,
            onDismissed: onDismissed,
            completion: completion
        )

        guard showingIdentifier == nil else {
            setPendingRequest(request)
            complete(request, with: .success(.queued))
            return
        }

        if presentIfPossible(request) {
            complete(request, with: .success(.displayed))
        } else {
            setPendingRequest(request)
            complete(request, with: .success(.queued))
            schedulePendingRetryIfNeeded()
        }
    }

    func dismiss(
        animated: Bool = true,
        cancelsPending: Bool = true,
        reason: InappMessagePresentationDismissReason = .programmatic
    ) {
        if cancelsPending {
            pendingRequest = nil
            pendingRetryWorkItem?.cancel()
            pendingRetryWorkItem = nil
        }

        guard overlayWindow.isShowing else {
            showingIdentifier = nil
            showingDispatcher = nil
            showingOnDismissed = nil
            return
        }

        currentDismissReason = reason
        overlayWindow.dismiss(animated: animated)
    }

    private func presentIfPossible(_ request: PresentationRequest) -> Bool {
        guard showingIdentifier == nil else { return false }
        guard let scene = resolveScene(for: request), canPresent(in: scene) else { return false }

        showingIdentifier = request.identifier
        showingDispatcher = request.actionDispatcher
        showingOnDismissed = request.onDismissed
        request.actionDispatcher.onRequestClose = { [weak self] _ in
            self?.dismiss(animated: true, cancelsPending: false, reason: .user)
        }

        let environment = InappMessageRenderEnvironment(
            debugGuidesEnabled: request.debugGuidesEnabled,
            actionDispatcher: request.actionDispatcher
        )

        overlayWindow.show(
            content: request.content,
            in: scene,
            environment: environment
        ) { [weak self, identifier = request.identifier] in
            self?.handleOverlayDismissed(identifier: identifier)
        }

        return true
    }

    private func setPendingRequest(_ request: PresentationRequest) {
        pendingRequest = request
    }

    private func complete(
        _ request: PresentationRequest,
        with result: Result<InappMessagePresentationResult, Error>
    ) {
        request.completion?(result)
        request.completion = nil
    }

    private func handleOverlayDismissed(identifier: String) {
        let dismissReason = currentDismissReason
        currentDismissReason = .programmatic
        var onDismissed: ((InappMessagePresentationDismissReason) -> Void)?

        if showingIdentifier == identifier {
            onDismissed = showingOnDismissed
            showingIdentifier = nil
            showingDispatcher?.onRequestClose = { _ in }
            showingDispatcher = nil
            showingOnDismissed = nil
        }

        onDismissed?(dismissReason)
        tryPresentPending()
    }

    private func tryPresentPending() {
        pendingRetryWorkItem?.cancel()
        pendingRetryWorkItem = nil

        guard showingIdentifier == nil, let request = pendingRequest else { return }

        if presentIfPossible(request) {
            pendingRequest = nil
        } else {
            schedulePendingRetryIfNeeded()
        }
    }

    private func schedulePendingRetryIfNeeded() {
        guard pendingRequest != nil, pendingRetryWorkItem == nil else { return }
        guard UIApplication.shared.applicationState == .active else { return }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.pendingRetryWorkItem = nil
                self?.tryPresentPending()
            }
        }
        pendingRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + retryInterval, execute: workItem)
    }

    private func resolveScene(for request: PresentationRequest) -> UIWindowScene? {
        if let preferredScene = request.preferredScene {
            return preferredScene
        }

        if let presenterScene = request.presenter?.view.window?.windowScene {
            return presenterScene
        }

        return UIApplication.shared.inappMessageForegroundWindowScene
    }

    private func canPresent(in scene: UIWindowScene) -> Bool {
        guard UIApplication.shared.applicationState == .active else { return false }
        guard scene.activationState == .foregroundActive else { return false }
        guard !hasBlockingPresentedViewController(in: scene) else { return false }
        return true
    }

    private func hasBlockingPresentedViewController(in scene: UIWindowScene) -> Bool {
        guard let rootViewController = scene.inappMessagePresentationWindow?.rootViewController else {
            return false
        }

        if let presented = rootViewController.presentedViewController, !presented.isBeingDismissed {
            return true
        }

        return false
    }

    private func startObservingLifecycleIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.tryPresentPending() }
        })

        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleAppDidEnterBackground() }
        })

        observers.append(center.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.tryPresentPending() }
        })

        observers.append(center.addObserver(
            forName: UIScene.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let scene = notification.object as? UIWindowScene else { return }
            Task { @MainActor in self?.handleSceneDidDisconnect(scene) }
        })
    }

    private func handleAppDidEnterBackground() {
        pendingRequest = nil
        pendingRetryWorkItem?.cancel()
        pendingRetryWorkItem = nil

        if overlayWindow.isShowing {
            dismiss(animated: false, cancelsPending: true, reason: .lifecycle)
        }
    }

    private func handleSceneDidDisconnect(_ scene: UIWindowScene) {
        if overlayWindow.windowScene === scene {
            dismiss(animated: false, cancelsPending: true, reason: .lifecycle)
        }

        if pendingRequest?.preferredScene === scene {
            pendingRequest = nil
        }
    }
}

private extension UIApplication {
    var inappMessageForegroundWindowScene: UIWindowScene? {
        let foregroundScenes = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        return foregroundScenes.first { scene in
            scene.windows.contains { $0.isKeyWindow }
        } ?? foregroundScenes.first
    }
}

private extension UIWindowScene {
    var inappMessagePresentationWindow: UIWindow? {
        windows.first { window in
            window.isKeyWindow && !window.isHidden && window.windowLevel == .normal
        } ?? windows.first { window in
            !window.isHidden && window.windowLevel == .normal
        }
    }
}
