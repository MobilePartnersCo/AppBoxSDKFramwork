import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

enum InappMessageRenderScale {
    static let fontScale: CGFloat = 1.0
    static let spacingScale: CGFloat = 1.0
    static let minimumButtonHeight: CGFloat = 48

    static func fontSize(_ value: Double) -> CGFloat {
        CGFloat(value) * fontScale
    }

    static func lineHeight(fontSize: Double, multiplier: Double) -> CGFloat {
        CGFloat(fontSize) * fontScale * CGFloat(multiplier)
    }

    static func spacing(_ value: Double) -> CGFloat {
        CGFloat(value) * spacingScale
    }

    static func letterSpacing(_ value: Double) -> CGFloat {
        CGFloat(value) * fontScale
    }

    static func radius(_ value: Double) -> CGFloat {
        CGFloat(value) * spacingScale
    }
}
