import UIKit

@available(iOSApplicationExtension, unavailable)
final class AppBoxWatermarkOverlayPresenter: AppBoxWatermarkPresenting {
    static let shared = AppBoxWatermarkOverlayPresenter()

    private var sceneStore = AppBoxWatermarkSceneStore<ObjectIdentifier, AppBoxWatermarkPassThroughWindow>()
    private var isVisible = false
    private var frontURL: URL?
    private var observers = [NSObjectProtocol]()

    /// 동기화 재진입 차단 플래그.
    ///
    /// 창의 `isHidden`을 바꾸면 `UIWindow.didBecomeVisible/HiddenNotification`이 동기로 날아오고,
    /// 이 클래스가 그 알림을 듣고 있어 동기화 도중 자기 자신이 다시 불린다.
    /// 보관소 접근은 이미 안전하게 고쳤지만, 이 플래그로 불필요한 중첩 실행 자체를 끊는다.
    ///
    /// **중첩된 호출은 재시도 없이 버린다.** 삼켜지는 것은 사실상 전부 자기유발 알림이고
    /// 바깥 루프가 모든 Scene을 어차피 처리하므로 상태는 수렴한다. 다만 이 전제는
    /// 모든 진입점이 main에서 **비동기로** 들어온다는 데 기대고 있다
    /// (`AppBoxWatermarkManager`가 두 진입점 모두 `DispatchQueue.main.async`로 감싼다).
    /// 누군가 main에서 동기로 `showWatermark`를 부르도록 바꾸면, 진행 중이던 동기화에 밀려
    /// 새 `frontURL`이 일부 Scene에만 반영된 채 굳을 수 있다.
    private var isSynchronizing = false

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
        guard isVisible, !isSynchronizing else { return }
        isSynchronizing = true
        defer { isSynchronizing = false }

        let scenes = Self.foregroundWindowScenes()
        let activeSceneIDs = Set(scenes.map(ObjectIdentifier.init))

        // 보관소에서 빼는 것과 창을 정리하는 것을 분리한다.
        // 정리(isHidden 변경)가 알림을 발생시키므로 보관소 접근이 끝난 뒤에 해야 한다.
        let removed = sceneStore.removeWindows(excluding: activeSceneIDs)
        removed.forEach(clearWindow)

        scenes.forEach(synchronizeOverlayWindow(in:))
    }

    private func synchronizeOverlayWindow(in scene: UIWindowScene) {
        let sceneID = ObjectIdentifier(scene)
        let window: AppBoxWatermarkPassThroughWindow

        if let existing = sceneStore.existingWindow(for: sceneID) {
            window = existing
        } else {
            // 창 생성도 보관소 접근 밖에서 끝낸 뒤 넣는다.
            let created = AppBoxWatermarkPassThroughWindow(windowScene: scene)
            created.backgroundColor = .clear
            created.rootViewController = AppBoxWatermarkViewController(frontURL: frontURL)
            sceneStore.store(created, for: sceneID)
            window = created
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
        // 여기서도 보관소를 비운 뒤에 정리한다.
        let removed = sceneStore.removeAll()
        removed.forEach(clearWindow)
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

/// Scene별 워터마크 창 보관소.
///
/// **`mutating` 메서드 안에서 외부 콜백을 부르지 않는다.** 이 타입은 struct라
/// `mutating`이 실행되는 동안 배타적 접근이 걸리는데, 그 안에서 창을 정리하면
/// `isHidden` 변경이 `UIWindow.didBecomeHiddenNotification`을 동기로 발생시키고
/// 그 알림을 듣는 옵저버가 다시 이 보관소를 건드려 배타적 접근 위반으로 죽는다.
/// 그래서 제거 대상만 돌려주고 실제 정리는 호출부가 접근을 끝낸 뒤에 한다.
struct AppBoxWatermarkSceneStore<SceneID: Hashable, Window> {
    private(set) var windows = [SceneID: Window]()

    func existingWindow(for sceneID: SceneID) -> Window? {
        windows[sceneID]
    }

    mutating func store(_ window: Window, for sceneID: SceneID) {
        windows[sceneID] = window
    }

    /// 활성 Scene에 속하지 않는 창을 보관소에서 빼고 **목록으로 돌려준다.**
    /// 돌려받은 창의 정리는 호출부 책임이다.
    mutating func removeWindows(excluding activeSceneIDs: Set<SceneID>) -> [Window] {
        var removed = [Window]()
        for sceneID in Array(windows.keys) where !activeSceneIDs.contains(sceneID) {
            guard let window = windows.removeValue(forKey: sceneID) else { continue }
            removed.append(window)
        }
        return removed
    }

    /// 전부 빼고 목록으로 돌려준다. 정리는 호출부 책임이다.
    mutating func removeAll() -> [Window] {
        let all = Array(windows.values)
        windows.removeAll()
        return all
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
