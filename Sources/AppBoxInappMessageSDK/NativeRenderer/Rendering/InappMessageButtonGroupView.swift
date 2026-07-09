import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

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
    private let allowsLabelWrapping: Bool

    init(
        buttons: InappMessageRenderSpec.Buttons,
        environment: InappMessageRenderEnvironment,
        style: Style = .normal,
        allowsLabelWrapping: Bool? = nil
    ) {
        self.buttons = buttons
        self.environment = environment
        self.style = style
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
            onTap: { [environment] in
                environment.handle(button: buttonSpec, index: index)
            }
        )
        button.accessibilityIdentifier = "inapp-button-\(index)"

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
    private static let textBaselineOffset: CGFloat = 1.5

    private let label = UILabel()
    private let buttonSpec: InappMessageRenderSpec.Button
    private let allowsWrapping: Bool
    private let lineHeight: CGFloat
    private let contentInsets: NSDirectionalEdgeInsets
    private let onTap: () -> Void

    init(
        buttonSpec: InappMessageRenderSpec.Button,
        allowsWrapping: Bool,
        onTap: @escaping () -> Void
    ) {
        self.buttonSpec = buttonSpec
        self.allowsWrapping = allowsWrapping
        self.onTap = onTap
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
            height: max(InappMessageRenderScale.minimumButtonHeight, contentHeight)
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
        guard allowsWrapping else {
            return super.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: horizontalFittingPriority,
                verticalFittingPriority: verticalFittingPriority
            )
        }

        let targetWidth = horizontalFittingPriority == .required && targetSize.width > 0
            ? targetSize.width
            : label.intrinsicContentSize.width + contentInsets.leading + contentInsets.trailing
        let labelWidth = max(0, targetWidth - contentInsets.leading - contentInsets.trailing)
        let labelSize = label.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude))
        let contentHeight = ceil(max(lineHeight, labelSize.height) + contentInsets.top + contentInsets.bottom)

        return CGSize(
            width: ceil(targetWidth),
            height: max(InappMessageRenderScale.minimumButtonHeight, contentHeight)
        )
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        layer.masksToBounds = true
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        label.translatesAutoresizingMaskIntoConstraints = false
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

    @objc private func handleTap() {
        onTap()
    }

    private func apply(_ buttonSpec: InappMessageRenderSpec.Button) {
        backgroundColor = UIColor.inappMessageColor(buttonSpec.backgroundColor, fallback: .systemGreen)
        accessibilityLabel = buttonSpec.label

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
