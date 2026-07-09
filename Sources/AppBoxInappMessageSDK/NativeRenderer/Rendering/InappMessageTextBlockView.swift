import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

final class InappMessageTextBlockView: UIView {
    private let label = UILabel()
    private var text: InappMessageRenderSpec.Text
    private let topPadding: Double
    private let bottomPadding: Double
    private let preservesLineBreaks: Bool

    init(
        text: InappMessageRenderSpec.Text,
        topPadding: Double? = nil,
        bottomPadding: Double? = nil,
        preservesLineBreaks: Bool = true
    ) {
        self.text = text
        self.topPadding = topPadding ?? text.paddingV
        self.bottomPadding = bottomPadding ?? text.paddingV
        self.preservesLineBreaks = preservesLineBreaks
        super.init(frame: .zero)
        setup()
        apply(text)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.adjustsFontForContentSizeCategory = false
        addSubview(label)
    }

    private func apply(_ text: InappMessageRenderSpec.Text) {
        isHidden = !text.enabled
        let fontSize = InappMessageRenderScale.fontSize(text.fontSize)
        let font = InappMessageTypography.font(
            for: .inAppText(weight: text.fontWeight == .bold ? .bold : .regular),
            size: fontSize
        )
        label.font = font
        label.textColor = UIColor.inappMessageColor(text.color, fallback: .label)
        label.textAlignment = text.align.nsTextAlignment

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = text.align.nsTextAlignment
        paragraph.lineBreakMode = .byCharWrapping
        let requestedLineHeight = InappMessageRenderScale.lineHeight(fontSize: text.fontSize, multiplier: text.lineHeight)
        let resolvedLineHeight = max(requestedLineHeight, ceil(font.lineHeight))
        paragraph.minimumLineHeight = resolvedLineHeight
        paragraph.maximumLineHeight = resolvedLineHeight

        let content = preservesLineBreaks
            ? text.content
            : text.content.replacingOccurrences(of: "\n", with: " ")

        label.attributedText = NSAttributedString(
            string: content,
            attributes: [
                .font: font,
                .foregroundColor: label.textColor as Any,
                .kern: InappMessageRenderScale.letterSpacing(text.letterSpacing),
                .paragraphStyle: paragraph
            ]
        )

        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: InappMessageRenderScale.spacing(topPadding),
            leading: InappMessageRenderScale.spacing(text.paddingH),
            bottom: InappMessageRenderScale.spacing(bottomPadding),
            trailing: InappMessageRenderScale.spacing(text.paddingH)
        )

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            label.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
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
