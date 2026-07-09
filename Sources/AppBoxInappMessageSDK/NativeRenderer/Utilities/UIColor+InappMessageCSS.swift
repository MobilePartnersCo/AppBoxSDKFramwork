import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

extension UIColor {
    static func inappMessageColor(_ cssString: String, fallback: UIColor) -> UIColor {
        UIColor(cssString: cssString) ?? fallback
    }

    convenience init?(cssString: String) {
        let value = cssString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if value == "transparent" {
            self.init(white: 0, alpha: 0)
            return
        }

        if value.hasPrefix("#") {
            guard let color = UIColor.parseHexColor(value) else { return nil }
            self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            return
        }

        if value.hasPrefix("rgba(") || value.hasPrefix("rgb(") {
            guard let color = UIColor.parseRGBColor(value) else { return nil }
            self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            return
        }

        return nil
    }

    private static func parseHexColor(_ value: String) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        let hex = String(value.dropFirst())
        let expanded: String

        switch hex.count {
        case 3:
            expanded = hex.map { "\($0)\($0)" }.joined()
        case 4:
            expanded = hex.map { "\($0)\($0)" }.joined()
        case 6, 8:
            expanded = hex
        default:
            return nil
        }

        guard let integer = UInt64(expanded, radix: 16) else { return nil }

        if expanded.count == 8 {
            return (
                red: CGFloat((integer >> 24) & 0xFF) / 255,
                green: CGFloat((integer >> 16) & 0xFF) / 255,
                blue: CGFloat((integer >> 8) & 0xFF) / 255,
                alpha: CGFloat(integer & 0xFF) / 255
            )
        }

        return (
            red: CGFloat((integer >> 16) & 0xFF) / 255,
            green: CGFloat((integer >> 8) & 0xFF) / 255,
            blue: CGFloat(integer & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func parseRGBColor(_ value: String) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        guard
            let open = value.firstIndex(of: "("),
            let close = value.lastIndex(of: ")"),
            open < close
        else {
            return nil
        }

        let components = value[value.index(after: open)..<close]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard components.count == 3 || components.count == 4 else { return nil }
        guard
            let red = Double(components[0]),
            let green = Double(components[1]),
            let blue = Double(components[2])
        else {
            return nil
        }

        let alpha = components.count == 4 ? (Double(components[3]) ?? 1) : 1
        return (
            red: CGFloat(red.clamped(to: 0...255) / 255),
            green: CGFloat(green.clamped(to: 0...255) / 255),
            blue: CGFloat(blue.clamped(to: 0...255) / 255),
            alpha: CGFloat(alpha.clamped(to: 0...1))
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
