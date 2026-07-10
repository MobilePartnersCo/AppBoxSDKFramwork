import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

final class InappMessageOverlayWindow {
    private var window: UIWindow?
    private var overlayViewController: InappMessageOverlayViewController?
    private weak var previousKeyWindow: UIWindow?
    private var onDismissed: (() -> Void)?

    var windowScene: UIWindowScene? {
        window?.windowScene
    }

    var isShowing: Bool {
        overlayViewController != nil
    }

    func show(
        content: InappMessagePreparedContent,
        in windowScene: UIWindowScene,
        environment: InappMessageRenderEnvironment,
        onDismissed: @escaping () -> Void
    ) {
        dismiss(animated: false)

        let overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow.windowLevel = .normal + 1
        overlayWindow.backgroundColor = .clear
        previousKeyWindow = windowScene.windows.first { $0.isKeyWindow }
        self.onDismissed = onDismissed

        let viewController = InappMessageOverlayViewController(
            content: content,
            environment: environment
        ) { [weak self] in
            self?.clearWindow(notifyDismissed: true)
        }

        overlayWindow.rootViewController = viewController
        overlayWindow.isHidden = false
        window = overlayWindow
        overlayViewController = viewController
    }

    func dismiss(animated: Bool = true) {
        guard let overlayViewController else {
            clearWindow(notifyDismissed: false)
            return
        }
        overlayViewController.dismissOverlay(animated: animated)
    }

    func clearWithoutNotifying() {
        clearWindow(notifyDismissed: false)
    }

    private func clearWindow(notifyDismissed: Bool) {
        let currentWindow = window
        currentWindow?.isHidden = true

        if let previousKeyWindow, previousKeyWindow !== currentWindow, !previousKeyWindow.isHidden {
            previousKeyWindow.makeKey()
        }

        window = nil
        overlayViewController = nil
        previousKeyWindow = nil
        let dismissed = onDismissed
        onDismissed = nil

        if notifyDismissed {
            dismissed?()
        }
    }
}

private final class InappMessageOverlayViewController: UIViewController {
    private let content: InappMessagePreparedContent
    private let environment: InappMessageRenderEnvironment
    private let onDismissed: () -> Void
    private let dimView = UIView()
    private var containerView: InappMessageContainerView?
    private var bottomSafeAreaFillView: UIView?
    private var containerWidthConstraint: NSLayoutConstraint?
    private var containerHeightConstraint: NSLayoutConstraint?
    private var hasReportedImpression = false
    private var hasStartedAnimation = false
    private var isDismissingOverlay = false

    private var spec: InappMessageRenderSpec {
        content.spec
    }

    init(
        content: InappMessagePreparedContent,
        environment: InappMessageRenderEnvironment,
        onDismissed: @escaping () -> Void
    ) {
        self.content = content
        self.environment = environment
        self.onDismissed = onDismissed
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        installDimView()
        installContainerView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateContainerLayoutForCurrentBounds()
        animateIn()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateContainerLayoutForCurrentBounds()
    }

    func dismissOverlay(animated: Bool = true) {
        guard !isDismissingOverlay else { return }
        isDismissingOverlay = true

        let animations = {
            self.dimView.alpha = 0
            self.containerView?.alpha = 0
            self.bottomSafeAreaFillView?.alpha = 0
            self.containerView?.transform = self.dismissTransform()
        }

        let completion: (Bool) -> Void = { [onDismissed] _ in
            onDismissed()
        }

        if animated {
            UIView.animate(
                withDuration: 0.2,
                delay: 0,
                options: [.curveEaseIn],
                animations: animations,
                completion: completion
            )
        } else {
            animations()
            completion(true)
        }
    }

    private func installDimView() {
        dimView.translatesAutoresizingMaskIntoConstraints = false
        let rendersDim = spec.frame.dim.enabled && spec.frame.position != .fullscreen
        dimView.backgroundColor = rendersDim
            ? UIColor.inappMessageColor(spec.frame.dim.color, fallback: UIColor.black.withAlphaComponent(0.32))
            : .clear
        dimView.alpha = 0
        view.addSubview(dimView)
        dimView.pinInappMessageEdges(to: view)

        if spec.frame.dim.enabled, spec.frame.dim.closeOnTap, spec.frame.position != .fullscreen {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleDimTap))
            dimView.addGestureRecognizer(tap)
        }
    }

    private func installContainerView() {
        let container = InappMessageContainerView(content: content, environment: environment)
        container.alpha = 0
        view.addSubview(container)
        containerView = container

        let guide = view.safeAreaLayoutGuide

        switch spec.frame.position {
        case .fullscreen:
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: view.topAnchor),
                container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                container.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        case .bottom:
            let initialLayout = resolveContainerLayout()
            let width = container.widthAnchor.constraint(equalToConstant: initialLayout.width)
            let height = container.heightAnchor.constraint(equalToConstant: initialLayout.height)
            containerWidthConstraint = width
            containerHeightConstraint = height
            installBottomSafeAreaFillViewIfNeeded(for: container, guide: guide)
            NSLayoutConstraint.activate([
                container.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
                container.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
                width,
                height,
                container.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: 24),
            ])
        case .center:
            let initialLayout = resolveContainerLayout()
            let width = container.widthAnchor.constraint(equalToConstant: initialLayout.width)
            let height = container.heightAnchor.constraint(equalToConstant: initialLayout.height)
            containerWidthConstraint = width
            containerHeightConstraint = height

            NSLayoutConstraint.activate([
                container.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
                container.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
                width,
                container.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 24),
                container.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -24),
                container.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: 24),
                container.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -24),
                height
            ])
        }

        updateContainerLayoutForCurrentBounds()
    }

    private func installBottomSafeAreaFillViewIfNeeded(for container: InappMessageContainerView, guide: UILayoutGuide) {
        guard let fillColor = container.bottomSafeAreaFillColor else { return }

        let fillView = UIView()
        fillView.translatesAutoresizingMaskIntoConstraints = false
        fillView.backgroundColor = fillColor
        fillView.alpha = 0
        fillView.isUserInteractionEnabled = false
        view.insertSubview(fillView, belowSubview: container)
        bottomSafeAreaFillView = fillView

        NSLayoutConstraint.activate([
            fillView.topAnchor.constraint(equalTo: guide.bottomAnchor),
            fillView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            fillView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            fillView.widthAnchor.constraint(equalTo: container.widthAnchor)
        ])
    }

    private func updateContainerLayoutForCurrentBounds() {
        guard spec.frame.position != .fullscreen else { return }
        let layout = resolveContainerLayout()

        if let containerWidthConstraint, abs(containerWidthConstraint.constant - layout.width) > 0.5 {
            containerWidthConstraint.constant = layout.width
        }

        if let containerHeightConstraint, abs(containerHeightConstraint.constant - layout.height) > 0.5 {
            containerHeightConstraint.constant = layout.height
        }
    }

    private func resolveContainerLayout() -> InappMessageResolvedPresentationLayout {
        let bounds = currentLayoutBounds()
        return InappMessageResolvedPresentationLayout.resolve(
            content: content,
            bounds: bounds,
            safeAreaFrame: currentSafeAreaFrame(for: bounds),
            environment: environment
        )
    }

    private func currentLayoutBounds() -> CGRect {
        if view.bounds.width > 0, view.bounds.height > 0 {
            return view.bounds
        }

        if let windowBounds = view.window?.bounds,
           windowBounds.width > 0,
           windowBounds.height > 0 {
            return windowBounds
        }

        if let screenBounds = view.window?.windowScene?.screen.bounds,
           screenBounds.width > 0,
           screenBounds.height > 0 {
            return screenBounds
        }

        return UIScreen.main.bounds
    }

    private func currentSafeAreaFrame(for bounds: CGRect) -> CGRect {
        let layoutFrame = view.safeAreaLayoutGuide.layoutFrame
        if layoutFrame.width > 0, layoutFrame.height > 0 {
            return layoutFrame
        }

        return bounds.inset(by: view.safeAreaInsets)
    }

    private func animateIn() {
        guard let containerView, !hasStartedAnimation else { return }
        hasStartedAnimation = true
        view.layoutIfNeeded()

        containerView.transform = initialTransform()
        containerView.alpha = spec.frame.animation == .none ? 1 : 0

        let reportImpression = { [weak self] in
            guard let self, !self.hasReportedImpression else { return }
            self.hasReportedImpression = true
            self.environment.emit(InappMessageRenderEvent(type: .impression, component: self.spec.frame.position.rawValue))
        }

        if spec.frame.animation == .none {
            dimView.alpha = rendersDim ? 1 : 0
            containerView.transform = .identity
            bottomSafeAreaFillView?.alpha = 1
            reportImpression()
            return
        }

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: spec.frame.animation == .scaleIn ? 0.86 : 1,
            initialSpringVelocity: 0,
            options: [.curveEaseOut],
            animations: {
                self.dimView.alpha = self.rendersDim ? 1 : 0
                containerView.alpha = 1
                self.bottomSafeAreaFillView?.alpha = 1
                containerView.transform = .identity
            },
            completion: { _ in reportImpression() }
        )
    }

    private func initialTransform() -> CGAffineTransform {
        switch spec.frame.animation {
        case .slideUp:
            return CGAffineTransform(translationX: 0, y: view.bounds.height)
        case .slideDown:
            return CGAffineTransform(translationX: 0, y: -view.bounds.height)
        case .slideLeft:
            return CGAffineTransform(translationX: view.bounds.width, y: 0)
        case .scaleIn:
            return CGAffineTransform(scaleX: 0.92, y: 0.92)
        case .fadeIn, .none:
            return .identity
        }
    }

    private var rendersDim: Bool {
        spec.frame.dim.enabled && spec.frame.position != .fullscreen
    }

    private func dismissTransform() -> CGAffineTransform {
        switch spec.frame.position {
        case .bottom:
            return CGAffineTransform(translationX: 0, y: view.bounds.height)
        case .center:
            return CGAffineTransform(scaleX: 0.94, y: 0.94)
        case .fullscreen:
            return .identity
        }
    }

    @objc private func handleDimTap() {
        environment.handleDimTap()
    }
}
