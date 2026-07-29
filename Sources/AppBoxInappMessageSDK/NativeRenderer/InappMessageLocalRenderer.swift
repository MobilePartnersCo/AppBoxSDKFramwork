import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

struct InappMessageLocalRendererOptions {
    var presentationIdentifier: String
    var preferredScene: UIWindowScene?
    var openLinks: Bool
    var debugGuidesEnabled: Bool
    var eventContext: InappMessageEventContext?
    var eventReporter: InappMessageEventReporter?
    var onEvent: (InappMessageRenderEvent) -> Void
    var onDismissToday: (InappMessageRenderEvent) -> Void
    /// 액션 통지. `(action, actionValue)`를 넘긴다.
    var onEventAction: (String, String) -> Void
    var onDismissed: (InappMessagePresentationDismissReason) -> Void

    init(
        presentationIdentifier: String = "local",
        preferredScene: UIWindowScene? = nil,
        openLinks: Bool = false,
        debugGuidesEnabled: Bool = false,
        eventContext: InappMessageEventContext? = nil,
        eventReporter: InappMessageEventReporter? = .shared,
        onEvent: @escaping (InappMessageRenderEvent) -> Void = { _ in },
        onDismissToday: @escaping (InappMessageRenderEvent) -> Void = { _ in },
        onEventAction: @escaping (String, String) -> Void = { _, _ in },
        onDismissed: @escaping (InappMessagePresentationDismissReason) -> Void = { _ in }
    ) {
        self.presentationIdentifier = presentationIdentifier
        self.preferredScene = preferredScene
        self.openLinks = openLinks
        self.debugGuidesEnabled = debugGuidesEnabled
        self.eventContext = eventContext
        self.eventReporter = eventReporter
        self.onEvent = onEvent
        self.onDismissToday = onDismissToday
        self.onEventAction = onEventAction
        self.onDismissed = onDismissed
    }
}

enum InappMessageLocalRendererError: Error, Equatable {
    case invalidJSONString
    case presenterDeallocated
    case cancelled
}

@MainActor
final class InappMessageLocalRenderer {
    static let shared = InappMessageLocalRenderer()

    private let decoder: InappMessageRenderSpecDecoder
    private let preparationService: InappMessagePreparationService
    private let presentationCoordinator: InappMessagePresentationCoordinator
    private var prepareTask: Task<Void, Never>?

    init(
        decoder: InappMessageRenderSpecDecoder = InappMessageRenderSpecDecoder(),
        preparationService: InappMessagePreparationService = InappMessagePreparationService(),
        presentationCoordinator: InappMessagePresentationCoordinator? = nil
    ) {
        self.decoder = decoder
        self.preparationService = preparationService
        self.presentationCoordinator = presentationCoordinator ?? .shared
    }

    func show(
        jsonString: String,
        from presenter: UIViewController,
        options: InappMessageLocalRendererOptions = InappMessageLocalRendererOptions(),
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        guard let data = jsonString.data(using: .utf8) else {
            completion?(.failure(InappMessageLocalRendererError.invalidJSONString))
            return
        }

        show(jsonData: data, from: presenter, options: options, completion: completion)
    }

    func show(
        jsonData: Data,
        from presenter: UIViewController,
        options: InappMessageLocalRendererOptions = InappMessageLocalRendererOptions(),
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        do {
            let spec = try decoder.decode(jsonData)
            show(spec: spec, from: presenter, options: options, completion: completion)
        } catch {
            completion?(.failure(error))
        }
    }

    func show(
        spec: InappMessageRenderSpec,
        from presenter: UIViewController,
        options: InappMessageLocalRendererOptions = InappMessageLocalRendererOptions(),
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        prepareTask?.cancel()
        let normalizedSpec = spec.normalized()

        prepareTask = Task { [weak self, weak presenter] in
            guard let self else { return }

            do {
                let content = try await preparationService.prepare(spec: normalizedSpec)
                try Task.checkCancellation()

                guard let presenter else {
                    completion?(.failure(InappMessageLocalRendererError.presenterDeallocated))
                    return
                }

                let actionDispatcher = InappMessageActionDispatcher(
                    openLinks: options.openLinks,
                    onEvent: options.onEvent,
                    onEventBatch: { events in
                        options.eventReporter?.report(
                            renderEvents: events,
                            context: options.eventContext
                        )
                    },
                    onDismissToday: options.onDismissToday,
                    onEventAction: options.onEventAction
                )

                presentationCoordinator.show(
                    content: content,
                    from: presenter,
                    preferredScene: options.preferredScene,
                    identifier: options.presentationIdentifier,
                    debugGuidesEnabled: options.debugGuidesEnabled,
                    actionDispatcher: actionDispatcher,
                    onDismissed: options.onDismissed
                ) { result in
                    switch result {
                    case .success:
                        completion?(.success(()))
                    case .failure(let error):
                        completion?(.failure(error))
                    }
                }
                prepareTask = nil
            } catch is CancellationError {
                completion?(.failure(InappMessageLocalRendererError.cancelled))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    func dismiss(animated: Bool = true) {
        prepareTask?.cancel()
        prepareTask = nil
        presentationCoordinator.dismiss(animated: animated, cancelsPending: true, reason: .programmatic)
    }
}
