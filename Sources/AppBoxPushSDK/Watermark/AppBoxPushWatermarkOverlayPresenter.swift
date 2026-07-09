//
//  AppBoxPushWatermarkOverlayPresenter.swift
//  AppBoxPushSDK
//

import UIKit

@available(iOSApplicationExtension, unavailable)
final class AppBoxPushWatermarkOverlayPresenter: AppBoxPushWatermarkPresenting {
    static let shared = AppBoxPushWatermarkOverlayPresenter()

    private var overlayWindows = [ObjectIdentifier: AppBoxPushWatermarkPassThroughWindow]()
    private var isVisible = false
    private var observers = [NSObjectProtocol]()

    private init() {}

    func showWatermark() {
        performOnMain { [weak self] in
            guard let self else { return }
            self.isVisible = true
            self.startObservingLifecycleIfNeeded()
            self.synchronizeOverlayWindows()
        }
    }

    func hideWatermark() {
        performOnMain { [weak self] in
            guard let self else { return }
            self.isVisible = false
            self.clearAllWindows()
            self.stopObservingLifecycle()
        }
    }

    private func synchronizeOverlayWindows() {
        guard isVisible else { return }

        let scenes = Self.foregroundWindowScenes()
        let activeSceneIDs = Set(scenes.map(ObjectIdentifier.init))

        for sceneID in Array(overlayWindows.keys) where !activeSceneIDs.contains(sceneID) {
            clearWindow(for: sceneID)
        }

        scenes.forEach { synchronizeOverlayWindow(in: $0) }
    }

    private func synchronizeOverlayWindow(in scene: UIWindowScene) {
        let sceneID = ObjectIdentifier(scene)
        let window: AppBoxPushWatermarkPassThroughWindow

        if let existingWindow = overlayWindows[sceneID] {
            window = existingWindow
        } else {
            let viewController = AppBoxPushWatermarkViewController()
            let newWindow = AppBoxPushWatermarkPassThroughWindow(windowScene: scene)
            newWindow.backgroundColor = .clear
            newWindow.rootViewController = viewController
            overlayWindows[sceneID] = newWindow
            window = newWindow
        }

        refreshWindowLevel(for: window, in: scene)

        if window.isHidden {
            window.isHidden = false
        }
    }

    private func refreshWindowLevel(for window: AppBoxPushWatermarkPassThroughWindow, in scene: UIWindowScene) {
        let candidates = scene.windows.map {
            AppBoxPushWatermarkWindowLevelCandidate(
                rawLevel: $0.windowLevel.rawValue,
                isHidden: $0.isHidden,
                isWatermarkWindow: $0 is AppBoxPushWatermarkPassThroughWindow
            )
        }
        let targetLevel = AppBoxPushWatermarkWindowLevelCalculator.targetLevel(for: candidates)

        if window.windowLevel != targetLevel {
            window.windowLevel = targetLevel
        }
    }

    private func clearWindow(for sceneID: ObjectIdentifier) {
        guard let window = overlayWindows.removeValue(forKey: sceneID) else { return }
        window.isHidden = true
        window.rootViewController = nil
    }

    private func clearAllWindows() {
        let sceneIDs = Array(overlayWindows.keys)
        sceneIDs.forEach(clearWindow(for:))
    }

    private func startObservingLifecycleIfNeeded() {
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.synchronizeOverlayWindows()
        })

        observers.append(center.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.synchronizeOverlayWindows()
        })

        observers.append(center.addObserver(
            forName: UIScene.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let scene = notification.object as? UIWindowScene else {
                return
            }
            self.clearWindow(for: ObjectIdentifier(scene))
            self.synchronizeOverlayWindows()
        })

        observers.append(center.addObserver(
            forName: UIWindow.didBecomeVisibleNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.synchronizeOverlayWindows()
        })

        observers.append(center.addObserver(
            forName: UIWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.synchronizeOverlayWindows()
        })

        observers.append(center.addObserver(
            forName: UIWindow.didBecomeHiddenNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.synchronizeOverlayWindows()
        })
    }

    private func stopObservingLifecycle() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    private func performOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private static func foregroundWindowScenes() -> [UIWindowScene] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
    }
}

struct AppBoxPushWatermarkWindowLevelCandidate {
    let rawLevel: CGFloat
    let isHidden: Bool
    let isWatermarkWindow: Bool
}

enum AppBoxPushWatermarkWindowLevelCalculator {
    static let minimumRawLevel = UIWindow.Level.normal.rawValue + 2

    static func targetLevel(for candidates: [AppBoxPushWatermarkWindowLevelCandidate]) -> UIWindow.Level {
        let highestRawLevel = candidates
            .filter { !$0.isHidden && !$0.isWatermarkWindow }
            .map(\.rawLevel)
            .max()

        let targetRawLevel = max((highestRawLevel ?? UIWindow.Level.normal.rawValue) + 1, minimumRawLevel)
        return UIWindow.Level(rawValue: targetRawLevel)
    }
}

@available(iOSApplicationExtension, unavailable)
private final class AppBoxPushWatermarkPassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView === self || hitView === rootViewController?.view {
            return nil
        }
        return hitView
    }
}

@available(iOSApplicationExtension, unavailable)
private final class AppBoxPushWatermarkViewController: UIViewController {
    override func loadView() {
        view = AppBoxPushWatermarkPassThroughView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        installWatermarkButton()
    }

    private func installWatermarkButton() {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(AppBoxPushWatermarkMessageProvider.selectedText, for: .normal)
        button.setTitleColor(AppBoxPushWatermarkStyle.textColor, for: .normal)
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
        button.addTarget(self, action: #selector(openWatermarkExternalLink), for: .touchUpInside)

        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
            button.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -14)
        ])
    }

    @objc
    private func openWatermarkExternalLink() {
        guard let url = URL(string: "https://www.appboxapp.com/") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

private final class AppBoxPushWatermarkPassThroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { subview in
            guard !subview.isHidden, subview.alpha > 0.01, subview.isUserInteractionEnabled else {
                return false
            }

            let convertedPoint = subview.convert(point, from: self)
            return subview.point(inside: convertedPoint, with: event)
        }
    }
}

private enum AppBoxPushWatermarkMessageProvider {
    static let selectedText: String = {
        let messages = [
            "Powered by Appbox",
            "Appbox 플랜을 업그레이드하면 워터마크가 제거됩니다.",
            "이 앱은 Appbox로 제작되었습니다."
        ]

        return messages.randomElement() ?? "Powered by Appbox"
    }()
}

private enum AppBoxPushWatermarkStyle {
    static let textColor = UIColor(
        red: 153.0 / 255.0,
        green: 161.0 / 255.0,
        blue: 175.0 / 255.0,
        alpha: 1
    )
}
