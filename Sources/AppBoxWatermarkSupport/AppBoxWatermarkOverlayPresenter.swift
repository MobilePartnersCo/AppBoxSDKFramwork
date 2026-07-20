import UIKit

@available(iOSApplicationExtension, unavailable)
final class AppBoxWatermarkOverlayPresenter: AppBoxWatermarkPresenting {
    static let shared = AppBoxWatermarkOverlayPresenter()

    private var sceneStore = AppBoxWatermarkSceneStore<ObjectIdentifier, AppBoxWatermarkPassThroughWindow>()
    private var isVisible = false
    private var observers = [NSObjectProtocol]()

    private init() {}

    func showWatermark() {
        performOnMain { [weak self] in
            guard let self else { return }
            isVisible = true
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
            window.rootViewController = AppBoxWatermarkViewController()
            return window
        }

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
    override func loadView() { view = AppBoxWatermarkPassThroughView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(AppBoxWatermarkMessageProvider.selectedText, for: .normal)
        button.setTitleColor(AppBoxWatermarkStyle.textColor, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.titleLabel?.layer.shadowColor = UIColor.black.cgColor
        button.titleLabel?.layer.shadowOpacity = 0.6
        button.titleLabel?.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.titleLabel?.layer.shadowRadius = 6
        button.titleLabel?.layer.masksToBounds = false
        button.titleLabel?.layer.shouldRasterize = true
        button.titleLabel?.layer.rasterizationScale = UIScreen.main.scale
        button.contentHorizontalAlignment = .left
        button.addTarget(self, action: #selector(openLink), for: .touchUpInside)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
            button.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -14)
        ])
    }

    @objc private func openLink() {
        guard let url = URL(string: "https://www.appboxapp.com/") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
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

private enum AppBoxWatermarkMessageProvider {
    static let selectedText = [
        "Powered by Appbox",
        "Appbox 플랜을 업그레이드하면 워터마크가 제거됩니다.",
        "이 앱은 Appbox로 제작되었습니다."
    ].randomElement() ?? "Powered by Appbox"
}

private enum AppBoxWatermarkStyle {
    static let textColor = UIColor(
        red: 153.0 / 255.0,
        green: 161.0 / 255.0,
        blue: 175.0 / 255.0,
        alpha: 1
    )
}
