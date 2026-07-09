import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

enum InappMessageFontRole {
    case inAppText(weight: UIFont.Weight)
    case inAppButton
    case inAppIndicatorNumber
    case inAppImagePlaceholder

    case consoleTitle
    case consoleSubtitle
    case consoleStatus
    case consoleLogTitle
    case consoleGuideLabel
    case consoleButton
    case consoleLog
}

enum InappMessageTypography {
    static func font(for role: InappMessageFontRole, size: CGFloat? = nil) -> UIFont {
        switch role {
        case .inAppText(let weight):
            return UIFont.systemFont(ofSize: size ?? 14, weight: weight)
        case .inAppButton:
            return UIFont.systemFont(ofSize: size ?? 14, weight: .regular)
        case .inAppIndicatorNumber:
            return UIFont.systemFont(ofSize: size ?? 12, weight: .semibold)
        case .inAppImagePlaceholder:
            return UIFont.systemFont(ofSize: size ?? 13, weight: .medium)
        case .consoleTitle:
            return scaledPretendard(textStyle: .title1, weight: .bold, fallbackSize: 24)
        case .consoleSubtitle:
            return scaledPretendard(textStyle: .title3, weight: .regular, fallbackSize: 15)
        case .consoleStatus:
            return scaledPretendard(textStyle: .callout, weight: .medium, fallbackSize: 14)
        case .consoleLogTitle:
            return scaledPretendard(textStyle: .title3, weight: .semibold, fallbackSize: 17)
        case .consoleGuideLabel:
            return scaledPretendard(textStyle: .headline, weight: .semibold, fallbackSize: 16)
        case .consoleButton:
            return scaledPretendard(textStyle: .body, weight: .medium, fallbackSize: 17)
        case .consoleLog:
            return scaledMonospace(size: size ?? 12, weight: .regular)
        }
    }

    private static func scaledPretendard(textStyle: UIFont.TextStyle, weight: UIFont.Weight, fallbackSize: CGFloat) -> UIFont {
        let baseSize = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        let pretendardFont = UIFont.pretendard(size: baseSize == 0 ? fallbackSize : baseSize, weight: weight)
        return UIFontMetrics.default.scaledFont(for: pretendardFont)
    }

    private static func scaledMonospace(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let baseFont = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        return UIFontMetrics.default.scaledFont(for: baseFont)
    }
}

extension UIFont {
    static func pretendard(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let fontName: String
        switch weight {
        case .bold, .semibold, .heavy, .black:
            fontName = "Pretendard-Bold"
        default:
            fontName = "Pretendard-Regular"
        }

        return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }
}
