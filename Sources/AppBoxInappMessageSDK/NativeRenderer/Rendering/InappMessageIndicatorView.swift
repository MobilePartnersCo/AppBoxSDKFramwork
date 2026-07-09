import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

final class InappMessageIndicatorView: UIView {
    enum Axis {
        case horizontal
        case vertical
    }

    private let stackView = UIStackView()
    private let numberLabel = UILabel()
    private let style: InappMessageRenderSpec.IndicatorStyle
    private let axis: Axis
    private let lineFullWidth: Bool
    private let activeColor: UIColor
    private let inactiveColor: UIColor
    private let textColor: UIColor
    private var count: Int
    private var currentIndex: Int = 0

    init(image: InappMessageRenderSpec.Image, count: Int, axis: Axis = .horizontal) {
        self.style = image.indicatorStyle
        self.axis = axis
        self.lineFullWidth = image.indicatorStyle == .line && image.indicatorBarFullWidth
        self.activeColor = UIColor.inappMessageColor(image.indicatorColor, fallback: .white)
        self.inactiveColor = UIColor.inappMessageColor(image.indicatorInactiveColor, fallback: .systemGray)
        self.textColor = UIColor.inappMessageColor(image.indicatorTextColor, fallback: .white)
        self.count = count
        super.init(frame: .zero)
        setup()
        update(currentIndex: 0, count: count)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(currentIndex: Int, count: Int) {
        self.currentIndex = max(0, min(currentIndex, max(0, count - 1)))
        self.count = count

        switch style {
        case .dot, .line:
            rebuildSegments()
        case .number:
            numberLabel.text = "\(self.currentIndex + 1) / \(max(1, count))"
        case .none:
            isHidden = true
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = style == .none
        directionalLayoutMargins = axis == .vertical
            ? NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            : .zero

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = axis == .vertical ? .vertical : .horizontal
        stackView.alignment = .center
        stackView.distribution = lineFullWidth ? .fillEqually : .fill
        stackView.spacing = style == .line ? 3 : 6

        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.font = InappMessageTypography.font(for: .inAppIndicatorNumber)
        numberLabel.adjustsFontForContentSizeCategory = false
        numberLabel.textColor = textColor
        numberLabel.textAlignment = .center

        switch style {
        case .dot, .line:
            addSubview(stackView)
            if axis == .vertical, style == .dot {
                NSLayoutConstraint.activate([
                    stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
                    stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                    stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
                    stackView.topAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.topAnchor),
                    stackView.bottomAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor)
                ])
            } else {
                NSLayoutConstraint.activate([
                    stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
                    stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                    stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
                    stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
                ])
            }
        case .number:
            addSubview(numberLabel)
            numberLabel.pinInappMessageEdges(to: self, insets: NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            layer.cornerRadius = 12
            backgroundColor = UIColor.black.withAlphaComponent(0.24)
        case .none:
            break
        }
    }

    private func rebuildSegments() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for index in 0..<count {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = index == currentIndex ? activeColor : inactiveColor
            view.layer.cornerRadius = style == .dot ? 4 : 1.5

            let widthConstraint: NSLayoutConstraint
            let heightConstraint: NSLayoutConstraint
            switch style {
            case .dot:
                widthConstraint = view.widthAnchor.constraint(equalToConstant: 8)
                heightConstraint = view.heightAnchor.constraint(equalToConstant: 8)
            case .line:
                if axis == .vertical {
                    widthConstraint = view.widthAnchor.constraint(equalToConstant: 3)
                    heightConstraint = view.heightAnchor.constraint(greaterThanOrEqualToConstant: 12)
                } else {
                    widthConstraint = view.widthAnchor.constraint(greaterThanOrEqualToConstant: 12)
                    heightConstraint = view.heightAnchor.constraint(equalToConstant: 3)
                }
            case .number, .none:
                continue
            }

            NSLayoutConstraint.activate([widthConstraint, heightConstraint])

            stackView.addArrangedSubview(view)
        }
    }
}
