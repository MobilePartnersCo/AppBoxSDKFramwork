import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

final class InappMessageContainerView: UIView, UIScrollViewDelegate {
    private let content: InappMessagePreparedContent
    private let environment: InappMessageRenderEnvironment
    private let maskLayer = CAShapeLayer()
    private let outerStackView = UIStackView()
    private let topOutsideStackView = UIStackView()
    private let bottomOutsideStackView = UIStackView()
    private let cardSurfaceView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    private var cardSurfaceHeightConstraint: NSLayoutConstraint?
    private weak var normalImageView: UIView?
    private var normalImageHeightConstraint: NSLayoutConstraint?
    private var fixedImageHeightConstraint: NSLayoutConstraint?
    private var fixedButtonBarView: UIView?
    private weak var outsidePageIndicatorView: InappMessageIndicatorView?
    private var lastIntrinsicWidth: CGFloat = 0

    private var spec: InappMessageRenderSpec {
        content.spec
    }

    init(content: InappMessagePreparedContent, environment: InappMessageRenderEnvironment) {
        self.content = content
        self.environment = environment
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        outerStackView.layoutIfNeeded()
        updateNormalImageHeightConstraint()
        updateFixedImageHeightConstraint()
        applyCornerMask()

        if abs(bounds.width - lastIntrinsicWidth) > 0.5 {
            lastIntrinsicWidth = bounds.width
            updateCardSurfaceHeightConstraint()
            updateNormalImageHeightConstraint()
            updateFixedImageHeightConstraint()
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        guard spec.frame.position != .fullscreen else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }

        let fittingWidth = resolvedFittingWidth()
        let cardHeight = cardContentHeight(for: fittingWidth)
        let height = outsideHeight(for: topOutsideStackView, width: fittingWidth)
            + cardHeight
            + outsideHeight(for: bottomOutsideStackView, width: fittingWidth)
        return CGSize(width: UIView.noIntrinsicMetric, height: pixelAlignedHeight(height))
    }

    var bottomSafeAreaFillColor: UIColor? {
        guard spec.frame.position == .bottom,
              !hasBottomCornerRadius
        else {
            return nil
        }

        if usesBottomOutsideButtonSafeAreaFillColor,
           let firstButton = spec.card.buttons.buttons.first {
            return UIColor.inappMessageColor(firstButton.backgroundColor, fallback: .clear)
        }

        return UIColor.inappMessageColor(spec.card.backgroundColor, fallback: .systemBackground)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
        backgroundColor = .clear
        accessibilityIdentifier = "inapp-container"

        installOuterShellLayout()
        installCardSurface()

        if spec.card.image.enabled && spec.card.image.asBackground {
            outerStackView.addArrangedSubview(cardSurfaceView)
            installBackgroundImageLayout()
        } else if usesFullscreenCoverImageLayout {
            outerStackView.addArrangedSubview(cardSurfaceView)
            installFullscreenCoverImageLayout()
        } else if usesFullscreenFixedImageLayout {
            outerStackView.addArrangedSubview(cardSurfaceView)
            installFullscreenFixedImageLayout()
        } else {
            let buttonPlacement = resolvedButtonPlacement()
            installOutsideControls(position: .top, buttonPlacement: buttonPlacement)
            outerStackView.addArrangedSubview(cardSurfaceView)
            if usesFixedImageOnlySurfaceLayout(buttonPlacement: buttonPlacement) {
                installFixedImageOnlySurfaceLayout()
            } else if usesFixedImageTextLayout(buttonPlacement: buttonPlacement) {
                installFixedImageTextLayout(buttonPlacement: buttonPlacement)
            } else {
                installScrollingContentLayout(constrainsToSafeArea: shouldConstrainCardContentToSafeArea)
                installNormalContent(buttonPlacement: buttonPlacement)
            }
            installOutsideControls(position: .bottom, buttonPlacement: buttonPlacement)
        }

        installCardSurfaceHeightConstraintIfNeeded()
        installDebugGuidesIfNeeded()
        installCloseButtonIfNeeded()
    }

    private var usesFullscreenFixedImageLayout: Bool {
        let card = spec.card
        return spec.frame.position == .fullscreen
            && card.image.enabled
            && !card.image.asBackground
            && hasNormalText
    }

    private var usesFullscreenCoverImageLayout: Bool {
        let card = spec.card
        return spec.frame.position == .fullscreen
            && card.image.enabled
            && !card.image.asBackground
            && !hasNormalText
    }

    private var shouldConstrainCardContentToSafeArea: Bool {
        spec.frame.position == .bottom || spec.frame.position == .fullscreen
    }

    private var hasBottomCornerRadius: Bool {
        let radius = spec.frame.radius
        let bottomRight = radius.count > 2 ? radius[2] : 0
        let bottomLeft = radius.count > 3 ? radius[3] : 0
        return bottomRight > 0 || bottomLeft > 0
    }

    private var hasBottomOutsideIndicator: Bool {
        spec.card.image.enabled && spec.card.image.indicatorPlacement == .bottomOutside
    }

    private var isBottomOutsideButtonLastVisual: Bool {
        guard resolvedButtonPlacement() == .outsideBottom else { return false }
        guard hasBottomOutsideIndicator else { return true }
        return spec.card.outsideBottomOrder == .indicatorFirst
    }

    private var usesBottomOutsideButtonSafeAreaFillColor: Bool {
        let buttons = spec.card.buttons
        return isBottomOutsideButtonLastVisual
            && buttons.direction == .horizontal
            && buttons.align == .stretch
            && buttons.gap <= 0.5
            && buttons.buttons.count == 1
            && buttons.buttons.allSatisfy { $0.borderRadius <= 0.5 }
    }

    private func usesFixedImageOnlySurfaceLayout(buttonPlacement: InappMessageButtonPlacement) -> Bool {
        guard usesImageOnlyCardSurface else { return false }
        return !spec.frame.fitContentHeight || spec.frame.position == .center
    }

    private func usesFixedImageTextLayout(buttonPlacement: InappMessageButtonPlacement) -> Bool {
        let card = spec.card
        guard spec.frame.position != .fullscreen,
              card.image.enabled,
              !card.image.asBackground
        else {
            return false
        }

        return hasNormalText
    }

    private func cardContentHeight(for width: CGFloat) -> CGFloat {
        let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let stackSize = stackView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        let imageHeight = spec.card.image.enabled
            ? pixelAlignedImageHeight(for: width)
            : 0
        let fixedButtonHeight = fixedButtonBarHeight(for: width)

        let textHeight = pixelAlignedHeight(stackSize.height)
        let contentHeight: CGFloat
        if usesImageOnlyCardSurface {
            contentHeight = imageHeight
        } else if usesFixedImageTextLayout(buttonPlacement: resolvedButtonPlacement()) {
            contentHeight = imageHeight + textHeight
        } else {
            contentHeight = max(textHeight, imageHeight, 1)
        }
        return contentHeight + fixedButtonHeight
    }

    private var usesImageOnlyCardSurface: Bool {
        let card = spec.card
        guard card.image.enabled, !card.image.asBackground else { return false }

        let hasNormalTitle = card.title.enabled && card.title.layer == .normal
        let hasNormalBody = card.body.enabled && card.body.layer == .normal
        return !hasNormalTitle && !hasNormalBody
    }

    private var hasNormalText: Bool {
        let card = spec.card
        return (card.title.enabled && card.title.layer == .normal)
            || (card.body.enabled && card.body.layer == .normal)
    }

    private func fixedButtonBarHeight(for width: CGFloat) -> CGFloat {
        guard let fixedButtonBarView, !fixedButtonBarView.isHidden else { return 0 }

        let size = fixedButtonBarView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(size.height)
    }

    private func installCardSurfaceHeightConstraintIfNeeded() {
        guard spec.frame.fitContentHeight, spec.frame.position != .fullscreen else { return }

        let constraint = cardSurfaceView.heightAnchor.constraint(equalToConstant: cardContentHeight(for: resolvedFittingWidth()))
        constraint.priority = .defaultHigh
        constraint.isActive = true
        cardSurfaceHeightConstraint = constraint
    }

    private func updateCardSurfaceHeightConstraint() {
        guard let cardSurfaceHeightConstraint else { return }
        cardSurfaceHeightConstraint.constant = cardContentHeight(for: resolvedFittingWidth())
    }

    private func updateFixedImageHeightConstraint() {
        guard let fixedImageHeightConstraint else { return }
        let width = cardSurfaceView.bounds.width > 1 ? cardSurfaceView.bounds.width : resolvedFittingWidth()
        let containerHeight = cardSurfaceView.bounds.height > 1 ? cardSurfaceView.bounds.height : UIScreen.main.bounds.height
        fixedImageHeightConstraint.constant = fixedImageHeight(for: width, containerHeight: containerHeight)
    }

    private func updateNormalImageHeightConstraint() {
        guard let normalImageHeightConstraint else { return }
        let width = normalImageView?.bounds.width ?? 0
        normalImageHeightConstraint.constant = pixelAlignedImageHeight(for: width > 1 ? width : resolvedFittingWidth())
    }

    private func fixedImageHeight(for width: CGFloat, containerHeight: CGFloat) -> CGFloat {
        if spec.frame.position == .fullscreen {
            let percent = CGFloat(spec.card.fullscreenImageHeightPercent / 100)
            return pixelAlignedHeight(max(containerHeight, 1) * percent)
        }

        let aspectHeight = width / content.imageAspectRatio
        let maxHeight = max(containerHeight, 1) * 0.45
        return pixelAlignedHeight(min(aspectHeight, maxHeight))
    }

    private func pixelAlignedImageHeight(for width: CGFloat) -> CGFloat {
        pixelAlignedHeight(width / content.imageAspectRatio)
    }

    private func pixelAlignedHeight(_ height: CGFloat) -> CGFloat {
        let scale = max(window?.screen.scale ?? UIScreen.main.scale, 1)
        return max(1, ceil(height * scale) / scale)
    }

    private func physicalPixelLength() -> CGFloat {
        1 / max(window?.screen.scale ?? UIScreen.main.scale, 1)
    }

    private func outsideHeight(for stackView: UIStackView, width: CGFloat) -> CGFloat {
        guard !stackView.isHidden else { return 0 }
        let size = stackView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(size.height)
    }

    private func installOuterShellLayout() {
        outerStackView.translatesAutoresizingMaskIntoConstraints = false
        outerStackView.axis = .vertical
        outerStackView.alignment = .fill
        outerStackView.distribution = .fill
        outerStackView.spacing = 0
        addSubview(outerStackView)
        outerStackView.pinInappMessageEdges(to: self)

        configureOutsideStack(topOutsideStackView)
        configureOutsideStack(bottomOutsideStackView)
    }

    private func configureOutsideStack(_ stackView: UIStackView) {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.isHidden = true
        stackView.setContentHuggingPriority(.required, for: .vertical)
        stackView.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func installCardSurface() {
        cardSurfaceView.translatesAutoresizingMaskIntoConstraints = false
        cardSurfaceView.clipsToBounds = true
        cardSurfaceView.backgroundColor = UIColor.inappMessageColor(spec.card.backgroundColor, fallback: .systemBackground)
        cardSurfaceView.setContentHuggingPriority(.defaultLow, for: .vertical)
        cardSurfaceView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        cardSurfaceView.accessibilityIdentifier = "inapp-card-surface"
    }

    private func resolvedFittingWidth() -> CGFloat {
        if bounds.width > 1 {
            return bounds.width
        }

        let screenWidth = UIScreen.main.bounds.width
        let percentWidth = screenWidth * CGFloat(spec.frame.widthPercent / 100)

        switch spec.frame.position {
        case .bottom:
            return max(1, percentWidth)
        case .center:
            return max(1, min(percentWidth, 520))
        case .fullscreen:
            return max(1, screenWidth)
        }
    }

    private func makeImageCarouselView(
        image: InappMessageRenderSpec.Image,
        preparedImages: [InappMessagePreparedImage],
        contentModeOverride: UIView.ContentMode? = nil,
        alignsFitContentToTop: Bool = false
    ) -> InappMessageImageCarouselView {
        InappMessageImageCarouselView(
            image: image,
            preparedImages: preparedImages,
            environment: environment,
            contentModeOverride: contentModeOverride,
            alignsFitContentToTop: alignsFitContentToTop,
            onIndexChanged: { [weak self] currentIndex, count in
                self?.outsidePageIndicatorView?.update(currentIndex: currentIndex, count: count)
            }
        )
    }

    private func installBackgroundImageLayout() {
        var backgroundImage = spec.card.image
        backgroundImage.images = Array(backgroundImage.images.prefix(1))
        backgroundImage.swipeEnabled = false
        backgroundImage.autoSlideMs = 0
        backgroundImage.indicatorStyle = .none

        let imageView = makeImageCarouselView(
            image: backgroundImage,
            preparedImages: Array(content.images.prefix(1)),
            contentModeOverride: .scaleAspectFill
        )
        cardSurfaceView.addSubview(imageView)
        imageView.pinInappMessageEdges(to: cardSurfaceView)
        imageView.layer.zPosition = 1

        installBackgroundBottomStack()
    }

    private func installBackgroundBottomStack() {
        let card = spec.card
        let hasContent = card.title.enabled || card.body.enabled || card.buttons.enabled
        guard hasContent else { return }

        let overlayStack = UIStackView()
        overlayStack.translatesAutoresizingMaskIntoConstraints = false
        overlayStack.axis = .vertical
        overlayStack.alignment = .fill
        overlayStack.distribution = .fill
        overlayStack.spacing = 12
        overlayStack.layer.zPosition = 2
        cardSurfaceView.addSubview(overlayStack)

        if card.title.enabled {
            overlayStack.addArrangedSubview(InappMessageTextBlockView(
                text: card.title,
                bottomPadding: 0,
                preservesLineBreaks: false
            ))
        }

        if card.body.enabled {
            overlayStack.addArrangedSubview(InappMessageTextBlockView(
                text: card.body,
                preservesLineBreaks: true
            ))
        }

        if card.buttons.enabled {
            var backgroundButtons = card.buttons
            backgroundButtons.vertical = .bottom
            backgroundButtons.layer = .normal
            overlayStack.addArrangedSubview(InappMessageButtonGroupView(
                buttons: backgroundButtons,
                environment: environment,
                style: .outside
            ))
        }

        NSLayoutConstraint.activate([
            overlayStack.leadingAnchor.constraint(equalTo: cardSurfaceView.leadingAnchor, constant: 16),
            overlayStack.trailingAnchor.constraint(equalTo: cardSurfaceView.trailingAnchor, constant: -16),
            overlayStack.topAnchor.constraint(greaterThanOrEqualTo: cardSurfaceView.topAnchor, constant: 16),
            overlayStack.bottomAnchor.constraint(equalTo: cardSurfaceView.bottomAnchor, constant: -16)
        ])
    }

    private func installFullscreenCoverImageLayout() {
        let buttonPlacement = resolvedButtonPlacement()
        let imageView = makeImageCarouselView(
            image: spec.card.image,
            preparedImages: content.images,
            contentModeOverride: .scaleAspectFill
        )
        cardSurfaceView.addSubview(imageView)
        imageView.pinInappMessageEdges(to: cardSurfaceView)
        imageView.layer.zPosition = 1

        installOverlayContentIfNeeded(on: imageView, buttonContainer: imageView)
        installFullscreenCoverEdgeControlsIfNeeded(position: .top, buttonPlacement: buttonPlacement)
        installFullscreenCoverEdgeControlsIfNeeded(position: .bottom, buttonPlacement: buttonPlacement)
    }

    private func installFullscreenFixedImageLayout() {
        let card = spec.card
        let buttonPlacement = resolvedButtonPlacement()
        let imageAreaView = UIView()
        imageAreaView.translatesAutoresizingMaskIntoConstraints = false
        imageAreaView.backgroundColor = UIColor.inappMessageColor(card.backgroundColor, fallback: .systemBackground)
        cardSurfaceView.addSubview(imageAreaView)

        let imageView = makeImageCarouselView(
            image: card.image,
            preparedImages: content.images,
            contentModeOverride: .scaleAspectFit,
            alignsFitContentToTop: true
        )
        imageAreaView.addSubview(imageView)

        let bottomControlsView = installFullscreenBottomControlsIfNeeded(buttonPlacement: buttonPlacement)

        let topControlsView = installFullscreenTopOutsideControlsIfNeeded(
            in: imageAreaView,
            buttonPlacement: buttonPlacement
        )

        let initialWidth = resolvedFittingWidth()
        let initialHeight = fixedImageHeight(
            for: initialWidth,
            containerHeight: UIScreen.main.bounds.height
        )
        let imageHeight = imageAreaView.heightAnchor.constraint(equalToConstant: initialHeight)
        fixedImageHeightConstraint = imageHeight

        var imageConstraints = [
            imageAreaView.topAnchor.constraint(equalTo: cardSurfaceView.topAnchor),
            imageAreaView.leadingAnchor.constraint(equalTo: cardSurfaceView.leadingAnchor),
            imageAreaView.trailingAnchor.constraint(equalTo: cardSurfaceView.trailingAnchor),
            imageHeight,

            imageView.leadingAnchor.constraint(equalTo: imageAreaView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageAreaView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageAreaView.bottomAnchor)
        ]

        if let topControlsView {
            imageConstraints.append(imageView.topAnchor.constraint(equalTo: topControlsView.bottomAnchor))
        } else {
            imageConstraints.append(imageView.topAnchor.constraint(equalTo: imageAreaView.topAnchor))
        }

        installTextScrollingContentLayout(
            topAnchor: imageAreaView.bottomAnchor,
            bottomAnchor: bottomControlsView?.topAnchor ?? cardSurfaceView.safeAreaLayoutGuide.bottomAnchor
        )
        imageView.layer.zPosition = 1
        installOverlayContentIfNeeded(on: imageView, buttonContainer: imageView)
        appendTextBlocks(
            title: card.title.layer == .overlay ? nil : card.title,
            body: card.body.layer == .overlay ? nil : card.body,
            to: stackView
        )

        NSLayoutConstraint.activate(imageConstraints)
    }

    @discardableResult
    private func installFullscreenTopOutsideControlsIfNeeded(
        in imageAreaView: UIView,
        buttonPlacement: InappMessageButtonPlacement
    ) -> UIView? {
        let buttonView = outsideButtonView(for: .top, buttonPlacement: buttonPlacement)
        let indicatorView = outsideIndicatorView(for: .top)

        guard buttonView != nil || indicatorView != nil else { return nil }

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.layer.zPosition = 3
        imageAreaView.addSubview(stackView)

        switch spec.card.outsideTopOrder {
        case .buttonFirst:
            addIfPresent(buttonView, to: stackView)
            addIfPresent(indicatorView, to: stackView)
        case .indicatorFirst:
            addIfPresent(indicatorView, to: stackView)
            addIfPresent(buttonView, to: stackView)
        case .stacked:
            stackView.addArrangedSubview(makeStackedOutsideControl(buttonView: buttonView, indicatorView: indicatorView))
        }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: imageAreaView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: imageAreaView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: imageAreaView.trailingAnchor)
        ])

        return stackView
    }

    @discardableResult
    private func installFullscreenCoverEdgeControlsIfNeeded(
        position: InappMessageOutsidePosition,
        buttonPlacement: InappMessageButtonPlacement
    ) -> UIView? {
        let buttonView: UIView?
        switch (position, buttonPlacement) {
        case (.top, .outsideTop):
            buttonView = makeOutsideButtonContainer(buttons: spec.card.buttons)
        case (.bottom, .outsideBottom):
            buttonView = makeFixedButtonGroupView()
        default:
            buttonView = nil
        }

        let indicatorView = outsideIndicatorView(for: position)
        guard buttonView != nil || indicatorView != nil else { return nil }

        let order: InappMessageRenderSpec.OutsideOrder
        switch position {
        case .top:
            order = spec.card.outsideTopOrder
        case .bottom:
            order = spec.card.outsideBottomOrder
        }

        let buttonFillsBottomSafeArea = position == .bottom
            && isButtonLastInBottomControls(
                buttonView: buttonView,
                indicatorView: indicatorView,
                order: order
            )

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        switch position {
        case .top:
            container.backgroundColor = .clear
        case .bottom:
            container.backgroundColor = buttonView != nil
                ? fixedButtonBarBackgroundColor(for: .fixedBar)
                : .clear
        }
        container.setContentHuggingPriority(.required, for: .vertical)
        container.setContentCompressionResistancePriority(.required, for: .vertical)
        container.layer.zPosition = 4

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0
        container.addSubview(stackView)
        installSegmentedFixedButtonSafeAreaFillIfNeeded(
            in: container,
            buttonFillsBottomSafeArea: buttonFillsBottomSafeArea
        )

        switch order {
        case .buttonFirst:
            addIfPresent(buttonView, to: stackView)
            addIfPresent(indicatorView, to: stackView)
        case .indicatorFirst:
            addIfPresent(indicatorView, to: stackView)
            addIfPresent(buttonView, to: stackView)
        case .stacked:
            stackView.addArrangedSubview(makeStackedOutsideControl(buttonView: buttonView, indicatorView: indicatorView))
        }

        cardSurfaceView.addSubview(container)
        if case .bottom = position {
            fixedButtonBarView = container
        }

        let guide = container.safeAreaLayoutGuide
        var constraints = [
            container.leadingAnchor.constraint(equalTo: cardSurfaceView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: cardSurfaceView.trailingAnchor),
            stackView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: guide.trailingAnchor)
        ]

        switch position {
        case .top:
            constraints += [
                container.topAnchor.constraint(equalTo: cardSurfaceView.topAnchor),
                stackView.topAnchor.constraint(equalTo: guide.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ]
        case .bottom:
            constraints += [
                container.bottomAnchor.constraint(equalTo: cardSurfaceView.bottomAnchor),
                stackView.topAnchor.constraint(equalTo: container.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
            ]
        }

        NSLayoutConstraint.activate(constraints)
        cardSurfaceView.bringSubviewToFront(container)
        return container
    }

    private func installFullscreenBottomControlsIfNeeded(buttonPlacement: InappMessageButtonPlacement) -> UIView? {
        let buttonView = buttonPlacement == .outsideBottom ? makeFixedButtonGroupView() : nil
        let indicatorView = outsideIndicatorView(for: .bottom)

        guard buttonView != nil || indicatorView != nil else { return nil }

        let buttonFillsBottomSafeArea = isButtonLastInBottomControls(
            buttonView: buttonView,
            indicatorView: indicatorView,
            order: spec.card.outsideBottomOrder
        )

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = fixedButtonBarBackgroundColor(for: .fixedBar)
        container.setContentHuggingPriority(.required, for: .vertical)
        container.setContentCompressionResistancePriority(.required, for: .vertical)

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0
        container.addSubview(stackView)
        installSegmentedFixedButtonSafeAreaFillIfNeeded(
            in: container,
            buttonFillsBottomSafeArea: buttonFillsBottomSafeArea
        )

        switch spec.card.outsideBottomOrder {
        case .buttonFirst:
            addIfPresent(buttonView, to: stackView)
            addIfPresent(indicatorView, to: stackView)
        case .indicatorFirst:
            addIfPresent(indicatorView, to: stackView)
            addIfPresent(buttonView, to: stackView)
        case .stacked:
            stackView.addArrangedSubview(makeStackedOutsideControl(buttonView: buttonView, indicatorView: indicatorView))
        }

        cardSurfaceView.addSubview(container)
        fixedButtonBarView = container

        let guide = container.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: cardSurfaceView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: cardSurfaceView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: cardSurfaceView.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
        ])

        cardSurfaceView.bringSubviewToFront(container)
        return container
    }

    private func makeFixedButtonGroupView() -> UIView {
        let buttonView = InappMessageButtonGroupView(
            buttons: spec.card.buttons,
            environment: environment,
            style: .fixedBar,
            allowsLabelWrapping: false
        )
        buttonView.setContentHuggingPriority(.required, for: .vertical)
        buttonView.setContentCompressionResistancePriority(.required, for: .vertical)
        return buttonView
    }

    private func installFixedImageTextLayout(buttonPlacement: InappMessageButtonPlacement) {
        let card = spec.card
        let imageView = makeImageCarouselView(
            image: card.image,
            preparedImages: content.images,
            contentModeOverride: .scaleAspectFill
        )
        cardSurfaceView.addSubview(imageView)

        let height = imageView.heightAnchor.constraint(equalToConstant: pixelAlignedImageHeight(for: resolvedFittingWidth()))
        height.priority = .defaultHigh
        normalImageView = imageView
        normalImageHeightConstraint = height

        let bottomAnchor = shouldConstrainCardContentToSafeArea
            ? cardSurfaceView.safeAreaLayoutGuide.bottomAnchor
            : cardSurfaceView.bottomAnchor

        installTextScrollingContentLayout(
            topAnchor: imageView.bottomAnchor,
            bottomAnchor: bottomAnchor,
            topOffset: -physicalPixelLength()
        )
        imageView.layer.zPosition = 1
        installOverlayContentIfNeeded(on: imageView, buttonContainer: cardSurfaceView)
        appendTextBlocks(
            title: card.title.layer == .overlay ? nil : card.title,
            body: card.body.layer == .overlay ? nil : card.body,
            to: stackView
        )

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: cardSurfaceView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: cardSurfaceView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: cardSurfaceView.trailingAnchor),
            height
        ])
    }

    private func installFixedImageOnlySurfaceLayout() {
        let imageView = makeImageCarouselView(
            image: spec.card.image,
            preparedImages: content.images,
            contentModeOverride: .scaleAspectFill
        )
        cardSurfaceView.addSubview(imageView)
        imageView.pinInappMessageEdges(to: cardSurfaceView)
        imageView.layer.zPosition = 1
        installOverlayContentIfNeeded(on: imageView)
    }

    private func installFixedButtonContentLayout(constrainsToSafeArea: Bool = false) {
        let style: InappMessageButtonGroupView.Style = spec.frame.position == .fullscreen ? .fixedBar : .normal
        let buttonView = installFixedButtonBar(style: style, constrainsToSafeArea: constrainsToSafeArea)
        installScrollingContentLayout(
            constrainsToSafeArea: constrainsToSafeArea,
            bottomAnchorOverride: buttonView.topAnchor
        )
    }

    private func installFixedButtonBar(style: InappMessageButtonGroupView.Style, constrainsToSafeArea: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = fixedButtonBarBackgroundColor(for: style)
        container.setContentHuggingPriority(.required, for: .vertical)
        container.setContentCompressionResistancePriority(.required, for: .vertical)

        let buttonView = InappMessageButtonGroupView(
            buttons: spec.card.buttons,
            environment: environment,
            style: style,
            allowsLabelWrapping: false
        )
        buttonView.setContentHuggingPriority(.required, for: .vertical)
        buttonView.setContentCompressionResistancePriority(.required, for: .vertical)
        container.addSubview(buttonView)
        installSegmentedFixedButtonSafeAreaFillIfNeeded(
            in: container,
            buttonFillsBottomSafeArea: constrainsToSafeArea && style == .fixedBar
        )

        cardSurfaceView.addSubview(container)
        fixedButtonBarView = container

        let contentLeadingAnchor: NSLayoutXAxisAnchor
        let contentTrailingAnchor: NSLayoutXAxisAnchor
        let bottomAnchor: NSLayoutYAxisAnchor

        if constrainsToSafeArea {
            let guide = container.safeAreaLayoutGuide
            contentLeadingAnchor = guide.leadingAnchor
            contentTrailingAnchor = guide.trailingAnchor
            bottomAnchor = guide.bottomAnchor
        } else {
            contentLeadingAnchor = container.leadingAnchor
            contentTrailingAnchor = container.trailingAnchor
            bottomAnchor = container.bottomAnchor
        }

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: cardSurfaceView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: cardSurfaceView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: cardSurfaceView.bottomAnchor),

            buttonView.topAnchor.constraint(equalTo: container.topAnchor),
            buttonView.leadingAnchor.constraint(equalTo: contentLeadingAnchor),
            buttonView.trailingAnchor.constraint(equalTo: contentTrailingAnchor),
            buttonView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        cardSurfaceView.bringSubviewToFront(container)
        return container
    }

    private func fixedButtonBarBackgroundColor(for style: InappMessageButtonGroupView.Style) -> UIColor {
        guard style == .fixedBar,
              spec.card.buttons.direction == .horizontal,
              spec.card.buttons.align == .stretch,
              spec.card.buttons.buttons.count == 1,
              let firstButton = spec.card.buttons.buttons.first,
              spec.card.buttons.buttons.allSatisfy({ $0.borderRadius <= 0.5 })
        else {
            return .clear
        }

        return UIColor.inappMessageColor(firstButton.backgroundColor, fallback: .clear)
    }

    private func isButtonLastInBottomControls(
        buttonView: UIView?,
        indicatorView: UIView?,
        order: InappMessageRenderSpec.OutsideOrder
    ) -> Bool {
        guard buttonView != nil else { return false }
        guard indicatorView != nil else { return true }

        switch order {
        case .indicatorFirst:
            return true
        case .buttonFirst, .stacked:
            return false
        }
    }

    private func usesSegmentedFixedButtonSafeAreaFill() -> Bool {
        let buttons = spec.card.buttons
        return buttons.direction == .horizontal
            && buttons.align == .stretch
            && buttons.gap <= 0.5
            && buttons.buttons.count > 1
            && buttons.buttons.allSatisfy { $0.borderRadius <= 0.5 }
    }

    private func installSegmentedFixedButtonSafeAreaFillIfNeeded(
        in container: UIView,
        buttonFillsBottomSafeArea: Bool
    ) {
        guard buttonFillsBottomSafeArea,
              usesSegmentedFixedButtonSafeAreaFill()
        else {
            return
        }

        let fillerView = UIStackView()
        fillerView.translatesAutoresizingMaskIntoConstraints = false
        fillerView.axis = .horizontal
        fillerView.alignment = .fill
        fillerView.distribution = .fillEqually
        fillerView.spacing = 0

        spec.card.buttons.buttons.forEach { button in
            let segmentView = UIView()
            segmentView.translatesAutoresizingMaskIntoConstraints = false
            segmentView.backgroundColor = UIColor.inappMessageColor(button.backgroundColor, fallback: .clear)
            fillerView.addArrangedSubview(segmentView)
        }

        container.insertSubview(fillerView, at: 0)
        let guide = container.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            fillerView.topAnchor.constraint(equalTo: guide.bottomAnchor),
            fillerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            fillerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            fillerView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func installScrollingContentLayout(
        constrainsToSafeArea: Bool = false,
        bottomAnchorOverride: NSLayoutYAxisAnchor? = nil
    ) {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.isScrollEnabled = !usesImageOnlyCardSurface
        scrollView.showsVerticalScrollIndicator = scrollView.isScrollEnabled
        configureVerticalOnlyScrolling(scrollView)
        cardSurfaceView.addSubview(scrollView)

        let topAnchor: NSLayoutYAxisAnchor
        let leadingAnchor: NSLayoutXAxisAnchor
        let trailingAnchor: NSLayoutXAxisAnchor
        let bottomAnchor: NSLayoutYAxisAnchor

        if constrainsToSafeArea {
            let guide = cardSurfaceView.safeAreaLayoutGuide
            topAnchor = guide.topAnchor
            leadingAnchor = guide.leadingAnchor
            trailingAnchor = guide.trailingAnchor
            bottomAnchor = guide.bottomAnchor
        } else {
            topAnchor = cardSurfaceView.topAnchor
            leadingAnchor = cardSurfaceView.leadingAnchor
            trailingAnchor = cardSurfaceView.trailingAnchor
            bottomAnchor = cardSurfaceView.bottomAnchor
        }

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchorOverride ?? bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func installTextScrollingContentLayout(
        topAnchor: NSLayoutYAxisAnchor,
        bottomAnchor: NSLayoutYAxisAnchor,
        topOffset: CGFloat = 0
    ) {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.isScrollEnabled = !usesImageOnlyCardSurface
        scrollView.showsVerticalScrollIndicator = scrollView.isScrollEnabled
        configureVerticalOnlyScrolling(scrollView)
        cardSurfaceView.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: topOffset),
            scrollView.leadingAnchor.constraint(equalTo: cardSurfaceView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: cardSurfaceView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func resolvedButtonPlacement() -> InappMessageButtonPlacement {
        let card = spec.card
        guard card.buttons.enabled else { return .none }

        let hasImageSurface = card.image.enabled && !card.image.asBackground
        if card.buttons.layer == .overlay, hasImageSurface {
            return .overlay
        }

        switch card.buttons.vertical {
        case .top, .topCenter:
            return .outsideTop
        case .center, .bottomCenter, .bottom:
            return .outsideBottom
        }
    }

    private func installOutsideControls(position: InappMessageOutsidePosition, buttonPlacement: InappMessageButtonPlacement) {
        let card = spec.card

        let buttonView = outsideButtonView(for: position, buttonPlacement: buttonPlacement)
        let indicatorView = outsideIndicatorView(for: position)

        guard buttonView != nil || indicatorView != nil else { return }

        let targetStack: UIStackView
        let order: InappMessageRenderSpec.OutsideOrder

        switch position {
        case .top:
            targetStack = topOutsideStackView
            order = card.outsideTopOrder
        case .bottom:
            targetStack = bottomOutsideStackView
            order = card.outsideBottomOrder
        }

        if targetStack.superview == nil {
            switch position {
            case .top:
                outerStackView.addArrangedSubview(targetStack)
            case .bottom:
                outerStackView.addArrangedSubview(targetStack)
            }
        }

        targetStack.isHidden = false

        switch order {
        case .buttonFirst:
            addIfPresent(buttonView, to: targetStack)
            addIfPresent(indicatorView, to: targetStack)
        case .indicatorFirst:
            addIfPresent(indicatorView, to: targetStack)
            addIfPresent(buttonView, to: targetStack)
        case .stacked:
            targetStack.addArrangedSubview(makeStackedOutsideControl(buttonView: buttonView, indicatorView: indicatorView))
        }
    }

    private func outsideButtonView(for position: InappMessageOutsidePosition, buttonPlacement: InappMessageButtonPlacement) -> UIView? {
        switch (position, buttonPlacement) {
        case (.top, .outsideTop), (.bottom, .outsideBottom):
            return makeOutsideButtonContainer(buttons: spec.card.buttons)
        default:
            return nil
        }
    }

    private func makeOutsideButtonContainer(buttons: InappMessageRenderSpec.Buttons) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let buttonView = InappMessageButtonGroupView(buttons: buttons, environment: environment, style: .outside)
        container.addSubview(buttonView)

        var constraints = [
            buttonView.topAnchor.constraint(equalTo: container.topAnchor),
            buttonView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ]

        switch buttons.align {
        case .stretch:
            constraints += [
                buttonView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                buttonView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ]
        case .center:
            constraints.append(buttonView.centerXAnchor.constraint(equalTo: container.centerXAnchor))
        case .left, .leftCenter, .rightCenter, .right:
            constraints.append(NSLayoutConstraint(
                item: buttonView,
                attribute: .centerX,
                relatedBy: .equal,
                toItem: container,
                attribute: .trailing,
                multiplier: buttonGridRatio(for: buttons.align),
                constant: 0
            ))
        }

        NSLayoutConstraint.activate(constraints)
        addDebugGuideIfNeeded(to: container, title: "Button grid: 6", divisions: 6)
        return container
    }

    private func outsideIndicatorView(for position: InappMessageOutsidePosition) -> UIView? {
        guard spec.card.image.enabled else { return nil }

        switch (position, spec.card.image.indicatorPlacement) {
        case (.top, .topOutside), (.bottom, .bottomOutside):
            return makeOutsideIndicator(for: spec.card.image)
        default:
            return nil
        }
    }

    private func addIfPresent(_ view: UIView?, to stackView: UIStackView) {
        guard let view else { return }
        stackView.addArrangedSubview(view)
    }

    private func makeStackedOutsideControl(buttonView: UIView?, indicatorView: UIView?) -> UIView {
        guard let buttonView else {
            return indicatorView ?? UIView()
        }
        guard let indicatorView else {
            return buttonView
        }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(buttonView)
        buttonView.pinInappMessageEdges(to: container)

        container.addSubview(indicatorView)
        indicatorView.pinInappMessageEdges(to: container)

        return container
    }

    private func installNormalContent(buttonPlacement: InappMessageButtonPlacement) {
        let card = spec.card
        let imageView = card.image.enabled
            ? makeImageCarouselView(
                image: card.image,
                preparedImages: content.images,
                contentModeOverride: usesImageOnlyCardSurface ? .scaleAspectFill : nil
            )
            : nil

        if let imageView {
            stackView.addArrangedSubview(imageView)
            let height = imageView.heightAnchor.constraint(equalToConstant: pixelAlignedImageHeight(for: resolvedFittingWidth()))
            height.priority = .defaultHigh
            height.isActive = true
            normalImageView = imageView
            normalImageHeightConstraint = height
            imageView.layer.zPosition = 1
            stackView.setCustomSpacing(-physicalPixelLength(), after: imageView)
            installOverlayContentIfNeeded(on: imageView)
        }

        appendTextBlocks(
            title: card.title.layer == .overlay && imageView != nil ? nil : card.title,
            body: card.body.layer == .overlay && imageView != nil ? nil : card.body,
            to: stackView
        )

    }

    private func installOverlayContentIfNeeded(on imageView: InappMessageImageCarouselView, buttonContainer: UIView? = nil) {
        let card = spec.card
        let title = card.title.layer == .overlay ? card.title : nil
        let body = card.body.layer == .overlay ? card.body : nil
        let buttons = card.buttons.layer == .overlay && card.buttons.enabled ? card.buttons : nil
        let targetContainer = buttonContainer ?? cardSurfaceView

        guard title?.enabled == true || body?.enabled == true || buttons != nil else { return }

        if title?.enabled == true || body?.enabled == true {
            installImageOverlayText(title: title, body: body, on: targetContainer)
        }

        if let buttons {
            targetContainer.isUserInteractionEnabled = true
            installOverlayButtonGroup(buttons, on: targetContainer)
        }
    }

    private func installImageOverlayText(
        title: InappMessageRenderSpec.Text?,
        body: InappMessageRenderSpec.Text?,
        on container: UIView
    ) {
        let hasText = title?.enabled == true || body?.enabled == true
        guard hasText else { return }

        let overlayStack = UIStackView()
        overlayStack.translatesAutoresizingMaskIntoConstraints = false
        overlayStack.axis = .vertical
        overlayStack.alignment = .fill
        overlayStack.distribution = .fill
        overlayStack.spacing = 0
        overlayStack.isUserInteractionEnabled = false
        overlayStack.layer.zPosition = 2
        container.addSubview(overlayStack)

        appendTextBlocks(title: title, body: body, to: overlayStack)

        NSLayoutConstraint.activate([
            overlayStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            overlayStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            overlayStack.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor, constant: 16),
            overlayStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -16),
            overlayStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }

    private func installOverlayButtonGroup(_ buttons: InappMessageRenderSpec.Buttons, on container: UIView) {
        guard buttons.enabled else { return }

        let buttonView = InappMessageButtonGroupView(buttons: buttons, environment: environment, style: .outside)
        buttonView.layer.zPosition = 3
        container.addSubview(buttonView)
        container.bringSubviewToFront(buttonView)

        var constraints = [
            NSLayoutConstraint(
                item: buttonView,
                attribute: .centerY,
                relatedBy: .equal,
                toItem: container,
                attribute: .bottom,
                multiplier: buttonGridRatio(for: buttons.vertical),
                constant: 0
            )
        ]

        switch buttons.align {
        case .stretch:
            constraints += [
                buttonView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                buttonView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
            ]
        case .center:
            constraints.append(buttonView.centerXAnchor.constraint(equalTo: container.centerXAnchor))
        case .left, .leftCenter, .rightCenter, .right:
            constraints.append(NSLayoutConstraint(
                item: buttonView,
                attribute: .centerX,
                relatedBy: .equal,
                toItem: container,
                attribute: .trailing,
                multiplier: buttonGridRatio(for: buttons.align),
                constant: 0
            ))
        }

        NSLayoutConstraint.activate(constraints)
    }

    private func buttonGridRatio(for vertical: InappMessageRenderSpec.ButtonVerticalPlacement) -> CGFloat {
        switch vertical {
        case .top:
            return 1 / 6
        case .topCenter:
            return 2 / 6
        case .center:
            return 3 / 6
        case .bottomCenter:
            return 4 / 6
        case .bottom:
            return 5 / 6
        }
    }

    private func buttonGridRatio(for horizontal: InappMessageRenderSpec.ButtonHorizontalPlacement) -> CGFloat {
        switch horizontal {
        case .left:
            return 1 / 6
        case .leftCenter:
            return 2 / 6
        case .center, .stretch:
            return 3 / 6
        case .rightCenter:
            return 4 / 6
        case .right:
            return 5 / 6
        }
    }

    private func installCardOverlayText(
        title: InappMessageRenderSpec.Text?,
        body: InappMessageRenderSpec.Text?
    ) {
        let hasText = title?.enabled == true || body?.enabled == true
        guard hasText else { return }

        let overlayStack = UIStackView()
        overlayStack.translatesAutoresizingMaskIntoConstraints = false
        overlayStack.axis = .vertical
        overlayStack.alignment = .fill
        overlayStack.distribution = .fill
        overlayStack.spacing = 0
        overlayStack.isUserInteractionEnabled = false
        overlayStack.layer.zPosition = 2
        cardSurfaceView.addSubview(overlayStack)

        appendTextBlocks(title: title, body: body, to: overlayStack)

        NSLayoutConstraint.activate([
            overlayStack.leadingAnchor.constraint(equalTo: cardSurfaceView.leadingAnchor, constant: 16),
            overlayStack.trailingAnchor.constraint(equalTo: cardSurfaceView.trailingAnchor, constant: -16),
            overlayStack.topAnchor.constraint(greaterThanOrEqualTo: cardSurfaceView.topAnchor, constant: 16),
            overlayStack.bottomAnchor.constraint(lessThanOrEqualTo: cardSurfaceView.bottomAnchor, constant: -16),
            overlayStack.centerYAnchor.constraint(equalTo: cardSurfaceView.centerYAnchor)
        ])
    }

    private func installOverlayTextScroll(
        title: InappMessageRenderSpec.Text?,
        body: InappMessageRenderSpec.Text?,
        on imageView: InappMessageImageCarouselView
    ) {
        let textScrollView = UIScrollView()
        textScrollView.translatesAutoresizingMaskIntoConstraints = false
        textScrollView.alwaysBounceVertical = false
        textScrollView.showsVerticalScrollIndicator = true
        configureVerticalOnlyScrolling(textScrollView)
        imageView.overlayView.addSubview(textScrollView)
        imageView.overlayView.isUserInteractionEnabled = true

        let textContentView = UIView()
        textContentView.translatesAutoresizingMaskIntoConstraints = false
        textScrollView.addSubview(textContentView)

        let textStackView = UIStackView()
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.axis = .vertical
        textStackView.alignment = .fill
        textStackView.distribution = .fill
        textStackView.spacing = 0
        textContentView.addSubview(textStackView)
        appendTextBlocks(title: title, body: body, to: textStackView)

        NSLayoutConstraint.activate([
            textScrollView.topAnchor.constraint(equalTo: imageView.overlayView.topAnchor, constant: 12),
            textScrollView.leadingAnchor.constraint(equalTo: imageView.overlayView.leadingAnchor, constant: 12),
            textScrollView.trailingAnchor.constraint(equalTo: imageView.overlayView.trailingAnchor, constant: -12),
            textScrollView.bottomAnchor.constraint(equalTo: imageView.overlayView.bottomAnchor, constant: -12),

            textContentView.topAnchor.constraint(equalTo: textScrollView.contentLayoutGuide.topAnchor),
            textContentView.leadingAnchor.constraint(equalTo: textScrollView.contentLayoutGuide.leadingAnchor),
            textContentView.trailingAnchor.constraint(equalTo: textScrollView.contentLayoutGuide.trailingAnchor),
            textContentView.bottomAnchor.constraint(equalTo: textScrollView.contentLayoutGuide.bottomAnchor),
            textContentView.widthAnchor.constraint(equalTo: textScrollView.frameLayoutGuide.widthAnchor),

            textStackView.topAnchor.constraint(equalTo: textContentView.topAnchor),
            textStackView.leadingAnchor.constraint(equalTo: textContentView.leadingAnchor),
            textStackView.trailingAnchor.constraint(equalTo: textContentView.trailingAnchor),
            textStackView.bottomAnchor.constraint(equalTo: textContentView.bottomAnchor)
        ])
    }

    private func configureVerticalOnlyScrolling(_ scrollView: UIScrollView) {
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.delegate = self
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.contentOffset.x != 0 else { return }
        scrollView.contentOffset.x = 0
    }

    private func appendTextBlocks(
        title: InappMessageRenderSpec.Text?,
        body: InappMessageRenderSpec.Text?,
        to stack: UIStackView
    ) {
        let hasTitle = title?.enabled == true
        let hasBody = body?.enabled == true

        if let title, hasTitle {
            stack.addArrangedSubview(InappMessageTextBlockView(
                text: title,
                bottomPadding: 0,
                preservesLineBreaks: false
            ))
        }

        if hasTitle && hasBody {
            stack.addArrangedSubview(makeSpacer(height: spec.card.textGap))
        }

        if let body, hasBody {
            stack.addArrangedSubview(InappMessageTextBlockView(text: body, preservesLineBreaks: true))
        }
    }

    private func makeSpacer(height: Double) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    private func makeOutsideIndicator(for image: InappMessageRenderSpec.Image) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.inappMessageColor(image.indicatorBgColor, fallback: .clear)

        let indicator = InappMessageIndicatorView(image: image, count: image.images.count)
        outsidePageIndicatorView = indicator
        container.addSubview(indicator)

        let verticalPadding: CGFloat = image.indicatorStyle == .number ? 2 : 8
        let horizontalPadding: CGFloat = image.indicatorStyle == .number ? 8 : 4
        var constraints = [
            indicator.topAnchor.constraint(equalTo: container.topAnchor, constant: verticalPadding),
            indicator.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -verticalPadding)
        ]

        if image.indicatorStyle == .line, image.indicatorBarFullWidth {
            constraints += [
                indicator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalPadding),
                indicator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalPadding)
            ]
        } else {
            constraints += outsideIndicatorHorizontalConstraints(
                indicator: indicator,
                container: container,
                align: image.indicatorAlign,
                horizontalPadding: horizontalPadding
            )
        }

        NSLayoutConstraint.activate(constraints)

        return container
    }

    private func outsideIndicatorHorizontalConstraints(
        indicator: UIView,
        container: UIView,
        align: InappMessageRenderSpec.HorizontalPlacement,
        horizontalPadding: CGFloat
    ) -> [NSLayoutConstraint] {
        switch align {
        case .left:
            return [
                indicator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalPadding),
                indicator.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -horizontalPadding)
            ]
        case .leftCenter:
            return [
                NSLayoutConstraint(
                    item: indicator,
                    attribute: .leading,
                    relatedBy: .equal,
                    toItem: container,
                    attribute: .trailing,
                    multiplier: 0.2,
                    constant: horizontalPadding
                ),
                indicator.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -horizontalPadding)
            ]
        case .center, .leftEdge, .rightEdge, .stretch:
            return [
                indicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                indicator.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: horizontalPadding),
                indicator.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -horizontalPadding)
            ]
        case .rightCenter:
            return [
                NSLayoutConstraint(
                    item: indicator,
                    attribute: .trailing,
                    relatedBy: .equal,
                    toItem: container,
                    attribute: .trailing,
                    multiplier: 0.8,
                    constant: -horizontalPadding
                ),
                indicator.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: horizontalPadding)
            ]
        case .right:
            return [
                indicator.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: horizontalPadding),
                indicator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalPadding)
            ]
        }
    }

    private func installDebugGuidesIfNeeded() {
        guard environment.debugGuidesEnabled else { return }

        addDebugGuideIfNeeded(to: cardSurfaceView, title: "Card/Button grid: 6", divisions: 6)

        if !topOutsideStackView.isHidden {
            addDebugGuideIfNeeded(to: topOutsideStackView, title: "Outside top", divisions: 0, palette: .outside)
        }

        if !bottomOutsideStackView.isHidden {
            addDebugGuideIfNeeded(to: bottomOutsideStackView, title: "Outside bottom", divisions: 0, palette: .outside)
        }
    }

    private func addDebugGuideIfNeeded(
        to view: UIView,
        title: String,
        divisions: Int,
        palette: InappMessageDebugGuideView.Palette = .cardButton
    ) {
        guard environment.debugGuidesEnabled else { return }

        let guide = InappMessageDebugGuideView(title: title, divisions: divisions, palette: palette)
        view.addSubview(guide)
        guide.pinInappMessageEdges(to: view)
        view.bringSubviewToFront(guide)
    }

    private func installCloseButtonIfNeeded() {
        let closeButtonSpec = spec.card.closeButton
        guard closeButtonSpec.enabled else { return }

        let button = InappMessageCloseButton(closeButton: closeButtonSpec)
        button.layer.zPosition = 1000
        addSubview(button)

        let usesSafeArea = spec.frame.position == .fullscreen
        let leadingAnchor = usesSafeArea ? safeAreaLayoutGuide.leadingAnchor : self.leadingAnchor
        let trailingAnchor = usesSafeArea ? safeAreaLayoutGuide.trailingAnchor : self.trailingAnchor
        let topOffset = closeButtonSpec.offsetY
        let preferredTopConstraint = button.topAnchor.constraint(equalTo: topAnchor, constant: topOffset)

        var constraints = [preferredTopConstraint]

        if usesSafeArea {
            preferredTopConstraint.priority = .defaultHigh
            constraints.append(button.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor))
        }

        switch closeButtonSpec.position {
        case .topLeft:
            constraints.append(button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8))
        case .topRight:
            constraints.append(button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8))
        }

        NSLayoutConstraint.activate(constraints)
        bringSubviewToFront(button)

        button.onTap = { [environment] in
            environment.handleCloseButton()
        }
    }

    private func applyCornerMask() {
        guard cardSurfaceView.bounds.width > 0, cardSurfaceView.bounds.height > 0 else { return }
        let radii = spec.frame.radius.map { CGFloat($0) }
        maskLayer.frame = cardSurfaceView.bounds
        maskLayer.path = roundedRectPath(in: cardSurfaceView.bounds, radii: radii)
        cardSurfaceView.layer.mask = maskLayer
    }

    private func roundedRectPath(in rect: CGRect, radii: [CGFloat]) -> CGPath {
        guard rect.width > 0, rect.height > 0 else { return CGPath(rect: rect, transform: nil) }

        let maxRadius = min(rect.width, rect.height) / 2
        let topLeft = min(radii[safe: 0] ?? 0, maxRadius)
        let topRight = min(radii[safe: 1] ?? 0, maxRadius)
        let bottomRight = min(radii[safe: 2] ?? 0, maxRadius)
        let bottomLeft = min(radii[safe: 3] ?? 0, maxRadius)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(
                withCenter: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                radius: topRight,
                startAngle: -.pi / 2,
                endAngle: 0,
                clockwise: true
            )
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(
                withCenter: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                radius: bottomRight,
                startAngle: 0,
                endAngle: .pi / 2,
                clockwise: true
            )
        }

        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(
                withCenter: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                radius: bottomLeft,
                startAngle: .pi / 2,
                endAngle: .pi,
                clockwise: true
            )
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(
                withCenter: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                radius: topLeft,
                startAngle: .pi,
                endAngle: .pi * 1.5,
                clockwise: true
            )
        }

        path.close()
        return path.cgPath
    }
}

final class InappMessageDebugGuideView: UIView {
    enum LabelPosition {
        case topLeading
        case topTrailing
    }

    struct Palette {
        let outlineColor: UIColor
        let divisionColor: UIColor
        let centerColor: UIColor
        let labelColor: UIColor

        static let cardButton = Palette(
            outlineColor: .systemYellow,
            divisionColor: .systemOrange,
            centerColor: .systemBlue,
            labelColor: .systemYellow
        )

        static let indicator = Palette(
            outlineColor: .systemGreen,
            divisionColor: .systemTeal,
            centerColor: .systemPurple,
            labelColor: .systemGreen
        )

        static let outside = Palette(
            outlineColor: .cyan,
            divisionColor: .systemTeal,
            centerColor: .systemBlue,
            labelColor: .cyan
        )
    }

    private let titleLabel = UILabel()
    private let title: String
    private let divisions: Int
    private let palette: Palette
    private let labelPosition: LabelPosition

    init(
        title: String,
        divisions: Int,
        palette: Palette = .cardButton,
        labelPosition: LabelPosition = .topLeading
    ) {
        self.title = title
        self.divisions = divisions
        self.palette = palette
        self.labelPosition = labelPosition
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), rect.width > 0, rect.height > 0 else { return }

        let lineWidth: CGFloat = 2
        let insetRect = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)

        context.setLineWidth(lineWidth)
        context.setStrokeColor(palette.outlineColor.withAlphaComponent(0.95).cgColor)
        context.stroke(insetRect)

        guard divisions > 1 else { return }

        for index in 1..<divisions {
            let ratio = CGFloat(index) / CGFloat(divisions)
            let isCenterLine = divisions.isMultiple(of: 2) && index == divisions / 2
            let lineColor = isCenterLine ? palette.centerColor : palette.divisionColor
            context.setStrokeColor(lineColor.withAlphaComponent(isCenterLine ? 0.82 : 0.45).cgColor)
            context.setLineWidth(lineWidth)

            let x = rect.minX + rect.width * ratio
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.strokePath()

            let y = rect.minY + rect.height * ratio
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.strokePath()
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.zPosition = 10_000
        accessibilityIdentifier = "inapp-debug-guide-\(title.replacingOccurrences(of: " ", with: "-").lowercased())"

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = " \(title) "
        titleLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = false
        titleLabel.textColor = palette.labelColor
        titleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.52)
        titleLabel.layer.cornerRadius = 4
        titleLabel.layer.masksToBounds = true
        addSubview(titleLabel)

        switch labelPosition {
        case .topLeading:
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4)
            ])
        case .topTrailing:
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
            ])
        }
    }
}

private enum InappMessageButtonPlacement: Equatable {
    case none
    case overlay
    case outsideTop
    case outsideBottom
}

private enum InappMessageOutsidePosition {
    case top
    case bottom
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
