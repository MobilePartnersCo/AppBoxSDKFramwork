import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

private struct InappMessageCarouselPage {
    let preparedImage: InappMessagePreparedImage
    let originalIndex: Int
}

private final class InappMessageHorizontalPagingScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        let velocity = panGestureRecognizer.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }
}

final class InappMessageImageCarouselView: UIView, UIScrollViewDelegate {
    let overlayView = UIView()

    private let scrollView = InappMessageHorizontalPagingScrollView()
    private let pageStackView = UIStackView()
    private let image: InappMessageRenderSpec.Image
    private let preparedImages: [InappMessagePreparedImage]
    private let pages: [InappMessageCarouselPage]
    private let environment: InappMessageRenderEnvironment
    private let contentModeOverride: UIView.ContentMode?
    private let alignsFitContentToTop: Bool
    private let onIndexChanged: ((Int, Int) -> Void)?
    private let indicatorView: InappMessageIndicatorView?
    private var autoSlideTimer: Timer?
    private var currentIndex = 0
    private var lastPageWidth: CGFloat = 0

    init(
        image: InappMessageRenderSpec.Image,
        preparedImages: [InappMessagePreparedImage],
        environment: InappMessageRenderEnvironment,
        contentModeOverride: UIView.ContentMode? = nil,
        alignsFitContentToTop: Bool = false,
        onIndexChanged: ((Int, Int) -> Void)? = nil
    ) {
        let resolvedImages = preparedImages.isEmpty
            ? image.images.map {
                InappMessagePreparedImage(item: $0, image: nil, pixelSize: nil, failureDescription: "Image was not prepared")
            }
            : preparedImages
        self.image = image
        self.preparedImages = resolvedImages
        if resolvedImages.count > 1, let first = resolvedImages.first, let last = resolvedImages.last {
            self.pages = [InappMessageCarouselPage(preparedImage: last, originalIndex: resolvedImages.count - 1)]
                + resolvedImages.enumerated().map { InappMessageCarouselPage(preparedImage: $0.element, originalIndex: $0.offset) }
                + [InappMessageCarouselPage(preparedImage: first, originalIndex: 0)]
        } else {
            self.pages = resolvedImages.enumerated().map { InappMessageCarouselPage(preparedImage: $0.element, originalIndex: $0.offset) }
        }
        self.environment = environment
        self.contentModeOverride = contentModeOverride
        self.alignsFitContentToTop = alignsFitContentToTop
        self.onIndexChanged = onIndexChanged
        self.indicatorView = image.indicatorPlacement == .overlay
            ? InappMessageIndicatorView(image: image, count: resolvedImages.count, axis: image.usesVerticalOverlayIndicator ? .vertical : .horizontal)
            : nil
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        if abs(bounds.width - lastPageWidth) > 0.5 {
            lastPageWidth = bounds.width
            scrollView.setContentOffset(offset(for: currentIndex), animated: false)
        }

        layoutOverlayIndicatorIfNeeded()
    }

    deinit {
        autoSlideTimer?.invalidate()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            autoSlideTimer?.invalidate()
            autoSlideTimer = nil
        } else {
            startAutoSlideIfNeeded()
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        let canScrollHorizontally = image.swipeEnabled && preparedImages.count > 1
        scrollView.bounces = canScrollHorizontally
        scrollView.isScrollEnabled = canScrollHorizontally
        scrollView.panGestureRecognizer.isEnabled = canScrollHorizontally
        scrollView.delegate = self
        addSubview(scrollView)
        scrollView.pinInappMessageEdges(to: self)

        pageStackView.translatesAutoresizingMaskIntoConstraints = false
        pageStackView.axis = .horizontal
        pageStackView.alignment = .fill
        pageStackView.distribution = .fill
        scrollView.addSubview(pageStackView)

        NSLayoutConstraint.activate([
            pageStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            pageStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            pageStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            pageStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            pageStackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let imageContentMode = resolvedImageContentMode()
        for pageInfo in pages {
            let page = InappMessagePreparedImageView(
                preparedImage: pageInfo.preparedImage,
                contentMode: imageContentMode,
                alignsFitContentToTop: alignsFitContentToTop
            )
            page.translatesAutoresizingMaskIntoConstraints = false
            pageStackView.addArrangedSubview(page)
            page.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true

            if preparedImages.count == 1 {
                let tap = UITapGestureRecognizer(target: self, action: #selector(handleImageTap(_:)))
                page.addGestureRecognizer(tap)
                page.isUserInteractionEnabled = true
            }
            page.tag = pageInfo.originalIndex
        }

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = resolvedOverlayDimColor()
        overlayView.isUserInteractionEnabled = false
        addSubview(overlayView)
        overlayView.pinInappMessageEdges(to: self)

        if let indicatorView {
            addSubview(indicatorView)
            indicatorView.translatesAutoresizingMaskIntoConstraints = true
        }

        installDebugGuideIfNeeded()
    }

    private func resolvedImageContentMode() -> UIView.ContentMode {
        if let contentModeOverride {
            return contentModeOverride
        }

        switch image.contentMode {
        case .fit:
            return .scaleAspectFit
        case .fill:
            return .scaleAspectFill
        }
    }

    private func resolvedOverlayDimColor() -> UIColor {
        let overlayDim = image.overlayDim.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard image.asBackground, overlayDim != "transparent" else {
            return .clear
        }

        return UIColor.inappMessageColor(image.overlayDim, fallback: .black)
    }

    private func layoutOverlayIndicatorIfNeeded() {
        guard let indicatorView,
              bounds.width > 0,
              bounds.height > 0
        else {
            return
        }

        let size = overlayIndicatorSize(for: indicatorView, in: bounds)
        let origin = overlayIndicatorOrigin(for: size, in: bounds)
        indicatorView.frame = pixelAligned(CGRect(origin: origin, size: size))
    }

    private func overlayIndicatorSize(for indicator: InappMessageIndicatorView, in contentRect: CGRect) -> CGSize {
        if image.usesVerticalOverlayIndicator {
            let height = max(1, contentRect.height - 8)
            let fittingSize = indicator.systemLayoutSizeFitting(
                CGSize(width: UIView.layoutFittingCompressedSize.width, height: height),
                withHorizontalFittingPriority: .fittingSizeLevel,
                verticalFittingPriority: .required
            )
            return CGSize(width: max(1, fittingSize.width), height: height)
        }

        if image.indicatorStyle == .line, image.indicatorBarFullWidth {
            let width = max(1, contentRect.width - 8)
            let fittingSize = indicator.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            return CGSize(width: width, height: max(1, fittingSize.height))
        }

        let fittingSize = indicator.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(width: max(1, fittingSize.width), height: max(1, fittingSize.height))
    }

    private func overlayIndicatorOrigin(for size: CGSize, in contentRect: CGRect) -> CGPoint {
        if image.usesVerticalOverlayIndicator {
            let y = contentRect.minY + 4
            let x: CGFloat
            switch image.indicatorAlign {
            case .right:
                x = contentRect.maxX - size.width
            case .left, .leftCenter, .center, .rightCenter, .leftEdge, .rightEdge, .stretch:
                x = contentRect.minX
            }
            return CGPoint(x: x, y: y)
        }

        let verticalRatio = indicatorGridRatio(for: image.indicatorVertical)
        let horizontalRatio = indicatorGridRatio(for: image.indicatorAlign)
        let centerY = contentRect.minY + contentRect.height * verticalRatio

        if image.indicatorStyle == .line, image.indicatorBarFullWidth {
            return CGPoint(
                x: contentRect.minX + 4,
                y: centerY - size.height / 2
            )
        }

        let centerX = contentRect.minX + contentRect.width * horizontalRatio
        return CGPoint(
            x: centerX - size.width / 2,
            y: centerY - size.height / 2
        )
    }

    private func pixelAligned(_ rect: CGRect) -> CGRect {
        let scale = max(window?.screen.scale ?? UIScreen.main.scale, 1)
        return CGRect(
            x: round(rect.origin.x * scale) / scale,
            y: round(rect.origin.y * scale) / scale,
            width: ceil(rect.width * scale) / scale,
            height: ceil(rect.height * scale) / scale
        )
    }

    private func installDebugGuideIfNeeded() {
        guard environment.debugGuidesEnabled,
              image.indicatorPlacement == .overlay,
              image.indicatorStyle != .none
        else {
            return
        }

        let guide = InappMessageDebugGuideView(
            title: "Indicator grid: 14",
            divisions: 14,
            palette: .indicator,
            labelPosition: .topTrailing
        )
        addSubview(guide)
        guide.pinInappMessageEdges(to: self)
        bringSubviewToFront(guide)

        if let indicatorView {
            bringSubviewToFront(indicatorView)
        }
    }

    private func indicatorGridRatio(for vertical: InappMessageRenderSpec.VerticalPlacement) -> CGFloat {
        switch vertical {
        case .topEdge:
            return 1 / 14
        case .top:
            return 3 / 14
        case .topCenter:
            return 5 / 14
        case .center:
            return 7 / 14
        case .bottomCenter:
            return 9 / 14
        case .bottom:
            return 11 / 14
        case .bottomEdge:
            return 13 / 14
        }
    }

    private func indicatorGridRatio(for horizontal: InappMessageRenderSpec.HorizontalPlacement) -> CGFloat {
        switch horizontal {
        case .leftEdge:
            return 1 / 14
        case .left:
            return 3 / 14
        case .leftCenter:
            return 5 / 14
        case .center, .stretch:
            return 7 / 14
        case .rightCenter:
            return 9 / 14
        case .right:
            return 11 / 14
        case .rightEdge:
            return 13 / 14
        }
    }

    private func startAutoSlideIfNeeded() {
        guard image.autoSlideMs > 0, preparedImages.count > 1, autoSlideTimer == nil else { return }
        autoSlideTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(image.autoSlideMs) / 1000,
            target: self,
            selector: #selector(advanceSlide),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func advanceSlide() {
        guard preparedImages.count > 1, bounds.width > 0 else { return }
        let nextIndex = (currentIndex + 1) % preparedImages.count
        let pageOverride = currentIndex == preparedImages.count - 1 ? pages.count - 1 : nil
        setCurrentIndex(nextIndex, animated: true, pageIndexOverride: pageOverride)
    }

    @objc private func handleImageTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard preparedImages.count == 1 else { return }
        let index = recognizer.view?.tag ?? currentIndex
        guard preparedImages.indices.contains(index) else { return }
        environment.handle(image: preparedImages[index].item, index: index)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateIndexFromContentOffset()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateIndexFromContentOffset()
    }

    private func updateIndexFromContentOffset() {
        guard bounds.width > 0 else { return }
        let pageIndex = Int(round(scrollView.contentOffset.x / bounds.width))
        if preparedImages.count > 1 {
            if pageIndex <= 0 {
                setCurrentIndex(preparedImages.count - 1, animated: false)
            } else if pageIndex >= pages.count - 1 {
                setCurrentIndex(0, animated: false)
            } else {
                setCurrentIndex(pageIndex - 1, animated: false)
            }
        } else {
            setCurrentIndex(pageIndex, animated: false)
        }
    }

    private func setCurrentIndex(_ index: Int, animated: Bool, pageIndexOverride: Int? = nil) {
        guard !preparedImages.isEmpty else { return }
        let clampedIndex = max(0, min(index, preparedImages.count - 1))
        currentIndex = clampedIndex
        indicatorView?.update(currentIndex: clampedIndex, count: preparedImages.count)
        onIndexChanged?(clampedIndex, preparedImages.count)
        setNeedsLayout()

        let pageIndex = pageIndexOverride ?? displayPageIndex(for: clampedIndex)
        let offset = CGPoint(x: CGFloat(pageIndex) * bounds.width, y: 0)
        if scrollView.contentOffset != offset {
            scrollView.setContentOffset(offset, animated: animated)
        }
    }

    private func offset(for index: Int) -> CGPoint {
        CGPoint(x: CGFloat(displayPageIndex(for: index)) * bounds.width, y: 0)
    }

    private func displayPageIndex(for index: Int) -> Int {
        preparedImages.count > 1 ? index + 1 : index
    }
}

private final class InappMessagePreparedImageView: UIView {
    private let imageView = UIImageView()
    private let placeholderLabel = UILabel()
    private let preparedImage: InappMessagePreparedImage
    private let preferredContentMode: UIView.ContentMode
    private let alignsFitContentToTop: Bool

    init(
        preparedImage: InappMessagePreparedImage,
        contentMode: UIView.ContentMode,
        alignsFitContentToTop: Bool
    ) {
        self.preparedImage = preparedImage
        self.preferredContentMode = contentMode
        self.alignsFitContentToTop = alignsFitContentToTop
        super.init(frame: .zero)
        setup(contentMode: contentMode)
        apply(preparedImage)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateImageFrame()
        updateImageContentMode()
    }

    private func setup(contentMode: UIView.ContentMode) {
        backgroundColor = .clear
        clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = alignsFitContentToTop
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        addSubview(imageView)
        if alignsFitContentToTop {
            updateImageFrame()
        } else {
            imageView.pinInappMessageEdges(to: self)
        }

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = "Image unavailable"
        placeholderLabel.font = InappMessageTypography.font(for: .inAppImagePlaceholder)
        placeholderLabel.adjustsFontForContentSizeCategory = false
        placeholderLabel.textColor = .secondaryLabel
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }

    private func apply(_ preparedImage: InappMessagePreparedImage) {
        if let image = preparedImage.image {
            imageView.image = image
            placeholderLabel.isHidden = true
        } else {
            imageView.image = nil
            placeholderLabel.text = preparedImage.item.alt.isEmpty
                ? (preparedImage.failureDescription ?? "Image unavailable")
                : preparedImage.item.alt
            placeholderLabel.isHidden = false
        }
    }

    private func updateImageContentMode() {
        imageView.contentMode = preferredContentMode
    }

    private func updateImageFrame() {
        guard alignsFitContentToTop else { return }
        guard
            preferredContentMode == .scaleAspectFit,
            let image = imageView.image,
            bounds.width > 0,
            bounds.height > 0,
            image.size.width > 0,
            image.size.height > 0
        else {
            imageView.frame = bounds
            return
        }

        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let fittedSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        imageView.frame = CGRect(
            x: (bounds.width - fittedSize.width) / 2,
            y: 0,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

private extension InappMessageRenderSpec.Image {
    var usesVerticalOverlayIndicator: Bool {
        indicatorPlacement == .overlay
            && indicatorVertical == .center
            && (indicatorAlign == .left || indicatorAlign == .right)
            && (indicatorStyle == .dot || indicatorStyle == .line)
    }
}
