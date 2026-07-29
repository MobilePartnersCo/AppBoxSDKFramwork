import UIKit

/// 상단 워터마크 스트립.
///
/// 흰색 채움 + 검은색 외곽선 텍스트를 오른쪽에서 왼쪽으로 끊김 없이 흘린다.
/// 배경은 완전히 투명하고, 스트립 전체가 탭 대상이다.
///
/// 이 뷰는 자기 크기만 책임진다. 어디에 놓을지는 상위(오버레이 뷰컨트롤러)가 정한다.
@available(iOSApplicationExtension, unavailable)
final class AppBoxWatermarkMarqueeView: UIView {
    /// marquee 애니메이션 키. 중복 추가와 해제를 이 키 하나로 관리한다.
    static let animationKey = "appbox.watermark.marquee"

    private let contentView = UIView()
    private let primaryLabel = UILabel()
    /// 이음매를 감추기 위한 두 번째 사본. 첫 사본이 왼쪽으로 빠져나가는 동안 오른쪽에서 들어온다.
    private let trailingLabel = UILabel()

    private let text: String
    private let onTap: (() -> Void)?

    /// 마지막으로 애니메이션을 구성한 크기. 같은 크기로 다시 레이아웃될 때
    /// 애니메이션을 재생성하지 않기 위해 기억한다. 재생성하면 위치가 처음으로 튄다.
    ///
    /// 주의: 이 가드는 **레이아웃 경로에만** 적용한다. 포그라운드 복귀처럼 크기는 그대로인데
    /// 애니메이션만 사라지는 경우가 있어, 그 경로는 가드를 건너뛰고 직접 재구성해야 한다.
    private var lastConfiguredBounds: CGRect = .zero

    private var lifecycleObservers = [NSObjectProtocol]()

    init(text: String, onTap: (() -> Void)?) {
        self.text = text
        self.onTap = onTap
        super.init(frame: .zero)

        backgroundColor = .clear
        clipsToBounds = true

        [primaryLabel, trailingLabel].forEach { label in
            label.attributedText = Self.makeAttributedText(text, displayScale: traitCollection.displayScale)
            label.numberOfLines = 1
            label.lineBreakMode = .byClipping
            label.backgroundColor = .clear
            label.isAccessibilityElement = false
            contentView.addSubview(label)
        }

        contentView.isUserInteractionEnabled = false
        addSubview(contentView)

        // 스트립 전체가 탭 영역이다. UIButton을 쓰지 않는 이유는 눌림 하이라이트를 없애기 위해서다.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true

        isAccessibilityElement = true
        accessibilityLabel = text
        accessibilityTraits = .link

        startObservingLifecycle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
    }

    /// 애니메이션이 사라지거나 정책이 바뀌는 경로를 관측한다.
    ///
    /// 두 부류를 **다르게** 다룬다. 같이 다루면 멀쩡히 흐르는 애니메이션까지 다시 만들어
    /// 문구가 처음 위치로 튄다.
    ///
    /// - 앱·Scene 활성화: iOS는 백그라운드 진입 시 레이어의 `CAAnimation`을 제거한다.
    ///   이때 뷰가 window에서 분리되지는 않으므로 `didMoveToWindow`는 발화하지 않고,
    ///   크기도 그대로라 레이아웃 경로만으로는 복구되지 않는다.
    ///   다만 제어센터·알림센터·앱스위처를 내렸다 올리는 경우에는 애니메이션이 살아 있으므로,
    ///   **없어졌을 때만** 되살린다.
    ///   `UIScene.didActivateNotification`은 iPad 멀티 Scene에서 개별 Scene만 복귀해
    ///   앱 수준 알림이 발화하지 않는 경우를 위한 것이다.
    /// - 동작 줄이기 변경: 켜짐/꺼짐 양방향이므로 상태와 무관하게 다시 판단해야 한다.
    private func startObservingLifecycle() {
        let center = NotificationCenter.default

        let activationNames: [Notification.Name] = [
            UIApplication.willEnterForegroundNotification,
            UIApplication.didBecomeActiveNotification,
            UIScene.didActivateNotification
        ]
        var observers = activationNames.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.restoreMarqueeIfMissing()
            }
        }

        observers.append(
            center.addObserver(
                forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reevaluateMarqueePolicy()
            }
        )

        lifecycleObservers = observers
    }

    /// 애니메이션이 실제로 사라졌을 때만 되살린다.
    ///
    /// 살아 있는데 다시 만들면 `removeAnimation` → `add` 과정에서 문구가 처음 위치로 되돌아간다.
    /// `removeAnimation(forKey:)`는 중복 *누적*은 막지만 이 위치 리셋은 막지 못한다.
    private func restoreMarqueeIfMissing() {
        guard contentView.layer.animation(forKey: Self.animationKey) == nil else { return }
        rebuildMarquee()
    }

    /// 동작 줄이기 정책은 상태와 무관하게 다시 판단한다.
    /// 켜졌으면 멈추고, 꺼졌으면 다시 흐르게 해야 한다.
    private func reevaluateMarqueePolicy() {
        rebuildMarquee()
    }

    /// 레이아웃 가드(`lastConfiguredBounds`)를 건너뛰고 직접 재구성한다.
    private func rebuildMarquee() {
        guard window != nil, bounds.width > 0 else { return }
        configureMarquee()
    }

    override var intrinsicContentSize: CGSize {
        let lineHeight = UIFont.systemFont(ofSize: AppBoxWatermarkLayout.fontSize, weight: .regular).lineHeight
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: ceil(lineHeight) + AppBoxWatermarkLayout.verticalPadding * 2
        )
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.displayScale != previousTraitCollection?.displayScale else { return }
        // 화면 배율이 달라지면 물리 픽셀 기준 외곽선 두께도 다시 계산해야 한다.
        let attributed = Self.makeAttributedText(text, displayScale: traitCollection.displayScale)
        primaryLabel.attributedText = attributed
        trailingLabel.attributedText = attributed
        lastConfiguredBounds = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.frame = bounds
        guard bounds != lastConfiguredBounds else { return }
        lastConfiguredBounds = bounds

        configureMarquee()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // 윈도우에서 떨어지면 CAAnimation이 제거된다. 다시 붙을 때 되살린다.
        if window != nil {
            lastConfiguredBounds = .zero
            setNeedsLayout()
        }
    }

    private func configureMarquee() {
        contentView.layer.removeAnimation(forKey: Self.animationKey)

        let textSize = primaryLabel.intrinsicContentSize
        let labelY = ((bounds.height - textSize.height) / 2).rounded()
        let containerWidth = bounds.width

        primaryLabel.frame = CGRect(x: 0, y: labelY, width: textSize.width, height: textSize.height)

        let shouldAnimate = AppBoxWatermarkMarqueeGeometry.shouldAnimate(
            textWidth: textSize.width,
            containerWidth: containerWidth
        ) && !UIAccessibility.isReduceMotionEnabled

        guard shouldAnimate else {
            // 동작 줄이기가 켜져 있거나 텍스트가 넘치지 않으면 흐르지 않는다.
            //
            // 이때 문구는 화면 폭을 넘는 만큼 잘린다. 폰트가 13pt 고정이라 축소할 수 없고,
            // "첫 문구만 표시"하는 대안 대신 **현재 동작을 유지하기로 결정**했다(2026-07-28).
            // 결함이 아니다. 자세한 배경은 docs/AppBoxWatermarkSupport/README.md 참고.
            trailingLabel.isHidden = true
            return
        }

        let travelDistance = AppBoxWatermarkMarqueeGeometry.travelDistance(
            textWidth: textSize.width,
            containerWidth: containerWidth
        )

        trailingLabel.isHidden = false
        trailingLabel.frame = CGRect(x: travelDistance, y: labelY, width: textSize.width, height: textSize.height)

        // 한 주기 끝의 화면이 시작과 같아지므로 이음매가 없다. 그래서 지연을 0으로 둬도 멈칫하지 않는다.
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -travelDistance
        animation.duration = AppBoxWatermarkMarqueeGeometry.duration(travelDistance: travelDistance)
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        contentView.layer.add(animation, forKey: Self.animationKey)
    }

    @objc private func handleTap() {
        onTap?()
    }

    /// 외곽선과 채움을 한 겹으로 그린다. 두 겹으로 나누면 층이 어긋날 수 있다.
    private static func makeAttributedText(_ text: String, displayScale: CGFloat) -> NSAttributedString {
        let fontSize = AppBoxWatermarkLayout.fontSize
        return NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: AppBoxWatermarkStrokePolicy.strokeWidthAttribute(
                    fontSize: fontSize,
                    displayScale: displayScale
                )
            ]
        )
    }
}
