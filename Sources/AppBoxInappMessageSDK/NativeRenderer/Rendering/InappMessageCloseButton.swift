import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

final class InappMessageCloseButton: UIButton {
    var onTap: (() -> Void)?

    init(closeButton: InappMessageRenderSpec.CloseButton) {
        super.init(frame: .zero)
        setup(closeButton: closeButton)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup(closeButton: InappMessageRenderSpec.CloseButton) {
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityLabel = "Close in-app message"
        accessibilityIdentifier = "inapp-close-button"

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        setImage(UIImage(systemName: "xmark", withConfiguration: symbolConfig), for: .normal)
        imageEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        imageView?.contentMode = .scaleAspectFit
        tintColor = UIColor.inappMessageColor(closeButton.color, fallback: .secondaryLabel)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 24),
            heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    @objc private func handleTap() {
        onTap?()
    }
}
