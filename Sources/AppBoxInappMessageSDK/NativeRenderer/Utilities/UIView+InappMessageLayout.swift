import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

extension UIView {
    func pinInappMessageEdges(to target: UIView, insets: NSDirectionalEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: target.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: target.leadingAnchor, constant: insets.leading),
            trailingAnchor.constraint(equalTo: target.trailingAnchor, constant: -insets.trailing),
            bottomAnchor.constraint(equalTo: target.bottomAnchor, constant: -insets.bottom)
        ])
    }
}
