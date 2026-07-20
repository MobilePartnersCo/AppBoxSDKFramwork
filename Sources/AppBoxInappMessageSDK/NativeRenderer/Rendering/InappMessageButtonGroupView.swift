import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

enum InappMessageButtonSizePolicy {
    case contentDriven
    case minimumCTAHeight

    var minimumVisualHeight: CGFloat {
        switch self {
        case .contentDriven:
            return 0
        case .minimumCTAHeight:
            return InappMessageRenderScale.minimumCTAButtonHeight
        }
    }

    var minimumInteractionHeight: CGFloat {
        switch self {
        case .contentDriven:
            return InappMessageRenderScale.minimumButtonTouchSize
        case .minimumCTAHeight:
            return InappMessageRenderScale.minimumCTAButtonHeight
        }
    }
}

final class InappMessageButtonGroupView: UIView {
    enum Style {
        case normal
        case outside
        case fixedBar
    }

    private let stackView = UIStackView()
    private let buttons: InappMessageRenderSpec.Buttons
    private let environment: InappMessageRenderEnvironment
    private let style: Style
    private let sizePolicy: InappMessageButtonSizePolicy
    private let allowsLabelWrapping: Bool

    init(
        buttons: InappMessageRenderSpec.Buttons,
        environment: InappMessageRenderEnvironment,
        style: Style = .normal,
        sizePolicy: InappMessageButtonSizePolicy = .minimumCTAHeight,
        allowsLabelWrapping: Bool? = nil
    ) {
        self.buttons = buttons
        self.environment = environment
        self.style = style
        self.sizePolicy = sizePolicy
        self.allowsLabelWrapping = allowsLabelWrapping ?? (style == .normal)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = !buttons.enabled
        directionalLayoutMargins = layoutMargins(for: style)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = buttons.direction == .horizontal ? .horizontal : .vertical
        stackView.spacing = InappMessageRenderScale.spacing(buttons.gap)
        stackView.alignment = stackAlignment()
        stackView.distribution = buttons.align == .stretch && buttons.direction == .horizontal ? .fillEqually : .fill
        stackView.setContentHuggingPriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(stackView)

        for (index, buttonSpec) in buttons.buttons.enumerated() {
            let button = makeButton(buttonSpec, index: index)
            stackView.addArrangedSubview(arrangedButtonView(for: button))
        }

        var constraints = [
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ]

        if buttons.direction == .vertical {
            constraints += [
                stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
            ]
        } else {
            switch buttons.align {
            case .stretch:
                constraints += [
                    stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                    stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
                ]
            case .left, .leftCenter:
                constraints += [
                    stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                    stackView.trailingAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor)
                ]
            case .right, .rightCenter:
                constraints += [
                    stackView.leadingAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.leadingAnchor),
                    stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
                ]
            case .center:
                constraints += [
                    stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
                    stackView.leadingAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.leadingAnchor),
                    stackView.trailingAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor)
                ]
            }
        }

        NSLayoutConstraint.activate(constraints)
    }

    private func arrangedButtonView(for button: UIView) -> UIView {
        guard buttons.direction == .vertical, buttons.align != .stretch else {
            return button
        }

        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(button)

        var constraints = [
            button.topAnchor.constraint(equalTo: row.topAnchor),
            button.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            button.leadingAnchor.constraint(greaterThanOrEqualTo: row.leadingAnchor),
            button.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor)
        ]

        switch buttons.align {
        case .left:
            constraints.append(button.leadingAnchor.constraint(equalTo: row.leadingAnchor))
        case .leftCenter:
            constraints.append(NSLayoutConstraint(
                item: button,
                attribute: .leading,
                relatedBy: .equal,
                toItem: row,
                attribute: .trailing,
                multiplier: 0.2,
                constant: 0
            ))
        case .center:
            constraints.append(button.centerXAnchor.constraint(equalTo: row.centerXAnchor))
        case .rightCenter:
            constraints.append(NSLayoutConstraint(
                item: button,
                attribute: .trailing,
                relatedBy: .equal,
                toItem: row,
                attribute: .trailing,
                multiplier: 0.8,
                constant: 0
            ))
        case .right:
            constraints.append(button.trailingAnchor.constraint(equalTo: row.trailingAnchor))
        case .stretch:
            break
        }

        NSLayoutConstraint.activate(constraints)
        return row
    }

    private func makeButton(_ buttonSpec: InappMessageRenderSpec.Button, index: Int) -> UIView {
        let button = InappMessageSpecButton(
            buttonSpec: buttonSpec,
            allowsWrapping: allowsLabelWrapping,
            stretchesHorizontally: buttons.align == .stretch,
            horizontalPlacement: buttons.align,
            sizePolicy: sizePolicy,
            onTap: { [environment] in
                environment.handle(button: buttonSpec, index: index)
            }
        )
        button.accessibilityIdentifier = "inapp-button-\(index)"
        button.visualSurfaceAccessibilityIdentifier = "inapp-button-visual-\(index)"

        return button
    }

    private func layoutMargins(for style: Style) -> NSDirectionalEdgeInsets {
        switch style {
        case .normal, .outside, .fixedBar:
            return .zero
        }
    }

    private func stackAlignment() -> UIStackView.Alignment {
        guard buttons.direction == .vertical else { return .fill }
        return .fill
    }
}

private final class InappMessageSpecButton: UIControl {
    private let visualSurface: InappMessageButtonVisualSurface
    private let stretchesHorizontally: Bool
    private let horizontalPlacement: InappMessageRenderSpec.ButtonHorizontalPlacement
    private let sizePolicy: InappMessageButtonSizePolicy
    private let onTap: () -> Void

    var visualSurfaceAccessibilityIdentifier: String? {
        get { visualSurface.accessibilityIdentifier }
        set { visualSurface.accessibilityIdentifier = newValue }
    }

    init(
        buttonSpec: InappMessageRenderSpec.Button,
        allowsWrapping: Bool,
        stretchesHorizontally: Bool,
        horizontalPlacement: InappMessageRenderSpec.ButtonHorizontalPlacement,
        sizePolicy: InappMessageButtonSizePolicy,
        onTap: @escaping () -> Void
    ) {
        visualSurface = InappMessageButtonVisualSurface(
            buttonSpec: buttonSpec,
            allowsWrapping: allowsWrapping,
            minimumVisualHeight: sizePolicy.minimumVisualHeight
        )
        self.stretchesHorizontally = stretchesHorizontally
        self.horizontalPlacement = horizontalPlacement
        self.sizePolicy = sizePolicy
        self.onTap = onTap
        super.init(frame: .zero)
        setup(buttonSpec: buttonSpec)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: CGSize {
        let visualSize = visualSurface.intrinsicContentSize
        return CGSize(
            width: max(InappMessageRenderScale.minimumButtonTouchSize, visualSize.width),
            height: max(sizePolicy.minimumInteractionHeight, visualSize.height)
        )
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let intrinsicVisualWidth = visualSurface.intrinsicContentSize.width
        let hasRequiredWidth = horizontalFittingPriority == .required && targetSize.width > 0
        let availableWidth = hasRequiredWidth ? targetSize.width : .greatestFiniteMagnitude

        let resolvedVisualWidth: CGFloat
        if stretchesHorizontally, hasRequiredWidth {
            resolvedVisualWidth = targetSize.width
        } else {
            resolvedVisualWidth = min(intrinsicVisualWidth, availableWidth)
        }

        let visualSize = visualSurface.systemLayoutSizeFitting(
            CGSize(width: resolvedVisualWidth, height: targetSize.height),
            withHorizontalFittingPriority: resolvedVisualWidth > 0 ? .required : horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )

        let naturalWrapperWidth = max(InappMessageRenderScale.minimumButtonTouchSize, visualSize.width)
        let wrapperWidth: CGFloat
        if stretchesHorizontally, hasRequiredWidth {
            wrapperWidth = targetSize.width
        } else if hasRequiredWidth {
            wrapperWidth = min(naturalWrapperWidth, targetSize.width)
        } else {
            wrapperWidth = naturalWrapperWidth
        }

        return CGSize(
            width: ceil(wrapperWidth),
            height: max(sizePolicy.minimumInteractionHeight, visualSize.height)
        )
    }

    private func setup(buttonSpec: InappMessageRenderSpec.Button) {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = buttonSpec.label
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        visualSurface.translatesAutoresizingMaskIntoConstraints = false
        visualSurface.isUserInteractionEnabled = false
        addSubview(visualSurface)

        var constraints = [
            visualSurface.centerYAnchor.constraint(equalTo: centerYAnchor),
            visualSurface.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            visualSurface.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ]

        switch horizontalPlacement {
        case .stretch:
            constraints += [
                visualSurface.leadingAnchor.constraint(equalTo: leadingAnchor),
                visualSurface.trailingAnchor.constraint(equalTo: trailingAnchor)
            ]
        case .left:
            constraints += [
                visualSurface.leadingAnchor.constraint(equalTo: leadingAnchor),
                visualSurface.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
            ]
        case .right:
            constraints += [
                visualSurface.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
                visualSurface.trailingAnchor.constraint(equalTo: trailingAnchor)
            ]
        case .leftCenter, .center, .rightCenter:
            constraints += [
                visualSurface.centerXAnchor.constraint(equalTo: centerXAnchor),
                visualSurface.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
                visualSurface.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
            ]
        }

        NSLayoutConstraint.activate(constraints)
    }

    @objc private func handleTap() {
        onTap()
    }

}

private final class InappMessageButtonVisualSurface: UIView {
    private static let textBaselineOffset: CGFloat = 1.5

    private let label = UILabel()
    private let buttonSpec: InappMessageRenderSpec.Button
    private let allowsWrapping: Bool
    private let minimumVisualHeight: CGFloat
    private let lineHeight: CGFloat
    private let contentInsets: NSDirectionalEdgeInsets

    init(
        buttonSpec: InappMessageRenderSpec.Button,
        allowsWrapping: Bool,
        minimumVisualHeight: CGFloat
    ) {
        self.buttonSpec = buttonSpec
        self.allowsWrapping = allowsWrapping
        self.minimumVisualHeight = minimumVisualHeight
        lineHeight = InappMessageRenderScale.lineHeight(fontSize: buttonSpec.fontSize, multiplier: 1.5)
        contentInsets = NSDirectionalEdgeInsets(
            top: InappMessageRenderScale.spacing(buttonSpec.paddingV),
            leading: InappMessageRenderScale.spacing(buttonSpec.paddingH),
            bottom: InappMessageRenderScale.spacing(buttonSpec.paddingV),
            trailing: InappMessageRenderScale.spacing(buttonSpec.paddingH)
        )
        super.init(frame: .zero)
        setup()
        apply(buttonSpec)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: CGSize {
        let textSize = label.intrinsicContentSize
        let contentHeight = ceil(lineHeight + contentInsets.top + contentInsets.bottom)
        return CGSize(
            width: ceil(textSize.width + contentInsets.leading + contentInsets.trailing),
            height: max(minimumVisualHeight, contentHeight)
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if allowsWrapping {
            label.preferredMaxLayoutWidth = max(0, bounds.width - contentInsets.leading - contentInsets.trailing)
        }
        layer.cornerRadius = min(InappMessageRenderScale.radius(buttonSpec.borderRadius), bounds.height / 2)
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let intrinsicWidth = label.intrinsicContentSize.width + contentInsets.leading + contentInsets.trailing
        let targetWidth = horizontalFittingPriority == .required && targetSize.width > 0
            ? targetSize.width
            : intrinsicWidth
        let labelWidth = max(0, targetWidth - contentInsets.leading - contentInsets.trailing)
        let measuredLabelHeight: CGFloat
        if allowsWrapping {
            measuredLabelHeight = label.sizeThatFits(
                CGSize(width: labelWidth, height: .greatestFiniteMagnitude)
            ).height
        } else {
            measuredLabelHeight = label.intrinsicContentSize.height
        }
        let contentHeight = ceil(max(lineHeight, measuredLabelHeight) + contentInsets.top + contentInsets.bottom)

        return CGSize(
            width: ceil(targetWidth),
            height: max(minimumVisualHeight, contentHeight)
        )
    }

    private func setup() {
        isUserInteractionEnabled = false
        layer.masksToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        label.isAccessibilityElement = false
        label.adjustsFontForContentSizeCategory = false
        label.numberOfLines = allowsWrapping ? 0 : 1
        label.lineBreakMode = allowsWrapping ? .byWordWrapping : .byTruncatingTail
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.leading),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.trailing),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom)
        ])
    }

    private func apply(_ buttonSpec: InappMessageRenderSpec.Button) {
        backgroundColor = UIColor.inappMessageColor(buttonSpec.backgroundColor, fallback: .systemGreen)

        let font = InappMessageTypography.font(
            for: .inAppButton,
            size: InappMessageRenderScale.fontSize(buttonSpec.fontSize)
        )
        let textColor = UIColor.inappMessageColor(buttonSpec.textColor, fallback: .white)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = buttonSpec.textAlign.nsTextAlignment
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight

        label.textAlignment = buttonSpec.textAlign.nsTextAlignment
        label.attributedText = NSAttributedString(
            string: buttonSpec.label,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraph,
                .baselineOffset: Self.textBaselineOffset
            ]
        )
    }
}

private extension InappMessageRenderSpec.TextAlign {
    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        }
    }
}
