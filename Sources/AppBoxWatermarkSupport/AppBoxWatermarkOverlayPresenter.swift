import UIKit

@available(iOSApplicationExtension, unavailable)
final class AppBoxWatermarkOverlayPresenter: AppBoxWatermarkPresenting {
    static let shared = AppBoxWatermarkOverlayPresenter()

    private var sceneStore = AppBoxWatermarkSceneStore<ObjectIdentifier, AppBoxWatermarkPassThroughWindow>()
    private var isVisible = false
    private var frontURL: URL?
    private var observers = [NSObjectProtocol]()

    private init() {}

    func showWatermark(frontURL: URL?) {
        performOnMain { [weak self] in
            guard let self else { return }
            isVisible = true
            self.frontURL = frontURL
            startObservingLifecycleIfNeeded()
            synchronizeOverlayWindows()
        }
    }

    func hideWatermark() {
        performOnMain { [weak self] in
            guard let self else { return }
            isVisible = false
            clearAllWindows()
            stopObservingLifecycle()
        }
    }

    private func synchronizeOverlayWindows() {
        guard isVisible else { return }
        let scenes = Self.foregroundWindowScenes()
        let activeSceneIDs = Set(scenes.map(ObjectIdentifier.init))
        sceneStore.removeWindows(excluding: activeSceneIDs) { window in
            clearWindow(window)
        }
        scenes.forEach(synchronizeOverlayWindow(in:))
    }

    private func synchronizeOverlayWindow(in scene: UIWindowScene) {
        let sceneID = ObjectIdentifier(scene)
        let window = sceneStore.window(for: sceneID) {
            let window = AppBoxWatermarkPassThroughWindow(windowScene: scene)
            window.backgroundColor = .clear
            window.rootViewController = AppBoxWatermarkViewController(frontURL: frontURL)
            return window
        }

        // 이미 만들어 둔 Scene의 창에도 최신 URL을 반영한다.
        (window.rootViewController as? AppBoxWatermarkViewController)?.updateFrontURL(frontURL)

        let candidates = scene.windows.map {
            AppBoxWatermarkWindowLevelCandidate(
                rawLevel: $0.windowLevel.rawValue,
                isHidden: $0.isHidden,
                isWatermarkWindow: $0 is AppBoxWatermarkPassThroughWindow
            )
        }
        window.windowLevel = AppBoxWatermarkWindowLevelCalculator.targetLevel(for: candidates)
        window.isHidden = false
    }

    private func clearWindow(_ window: AppBoxWatermarkPassThroughWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    private func clearAllWindows() {
        sceneStore.removeAll { window in
            clearWindow(window)
        }
    }

    private func startObservingLifecycleIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIApplication.didBecomeActiveNotification,
            UIScene.didActivateNotification,
            UIScene.didDisconnectNotification,
            UIWindow.didBecomeVisibleNotification,
            UIWindow.didBecomeKeyNotification,
            UIWindow.didBecomeHiddenNotification
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.synchronizeOverlayWindows()
            }
        }
    }

    private func stopObservingLifecycle() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    private func performOnMain(_ block: @escaping () -> Void) {
        Thread.isMainThread ? block() : DispatchQueue.main.async(execute: block)
    }

    private static func foregroundWindowScenes() -> [UIWindowScene] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
    }
}

struct AppBoxWatermarkSceneStore<SceneID: Hashable, Window> {
    private(set) var windows = [SceneID: Window]()

    mutating func window(for sceneID: SceneID, create: () -> Window) -> Window {
        if let window = windows[sceneID] { return window }
        let window = create()
        windows[sceneID] = window
        return window
    }

    mutating func removeWindows(excluding activeSceneIDs: Set<SceneID>, onRemove: (Window) -> Void) {
        for sceneID in Array(windows.keys) where !activeSceneIDs.contains(sceneID) {
            guard let window = windows.removeValue(forKey: sceneID) else { continue }
            onRemove(window)
        }
    }

    mutating func removeAll(onRemove: (Window) -> Void) {
        windows.values.forEach(onRemove)
        windows.removeAll()
    }
}

struct AppBoxWatermarkWindowLevelCandidate {
    let rawLevel: CGFloat
    let isHidden: Bool
    let isWatermarkWindow: Bool
}

enum AppBoxWatermarkWindowLevelCalculator {
    static let minimumRawLevel = UIWindow.Level.normal.rawValue + 2

    static func targetLevel(for candidates: [AppBoxWatermarkWindowLevelCandidate]) -> UIWindow.Level {
        let highestRawLevel = candidates
            .filter { !$0.isHidden && !$0.isWatermarkWindow }
            .map(\.rawLevel)
            .max()
        return UIWindow.Level(
            rawValue: max((highestRawLevel ?? UIWindow.Level.normal.rawValue) + 1, minimumRawLevel)
        )
    }
}

@available(iOSApplicationExtension, unavailable)
final class AppBoxWatermarkPassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        return hitView === self || hitView === rootViewController?.view ? nil : hitView
    }
}

@available(iOSApplicationExtension, unavailable)
private final class AppBoxWatermarkViewController: UIViewController {
    private var frontURL: URL?

    init(frontURL: URL?) {
        self.frontURL = frontURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() { view = AppBoxWatermarkPassThroughView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let marquee = AppBoxWatermarkMarqueeView(
            text: AppBoxWatermarkTextProvider.text,
            onTap: { [weak self] in self?.openFrontURL() }
        )
        marquee.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(marquee)

        // 세이프 에어리어 바로 아래, 가로 전체 폭. 높이는 뷰의 intrinsic 값을 쓴다.
        // 오버레이 창이므로 웹 콘텐츠나 고객 앱 레이아웃을 밀지 않는다.
        NSLayoutConstraint.activate([
            marquee.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            marquee.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            marquee.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func updateFrontURL(_ url: URL?) {
        frontURL = url
    }

    private func openFrontURL() {
        guard let frontURL else { return }
        // 열 수 없는 경우는 조용히 무시한다. 워터마크는 부가 요소이므로 사용자를 방해하지 않는다.
        UIApplication.shared.open(frontURL, options: [:], completionHandler: nil)
    }
}

final class AppBoxWatermarkPassThroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { subview in
            guard !subview.isHidden, subview.alpha > 0.01, subview.isUserInteractionEnabled else { return false }
            return subview.point(inside: subview.convert(point, from: self), with: event)
        }
    }
}
