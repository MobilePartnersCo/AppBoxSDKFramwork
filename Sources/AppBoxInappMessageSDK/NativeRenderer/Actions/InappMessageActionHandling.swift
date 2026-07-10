import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

enum InappMessageRenderEventType: String {
    case impression = "IMPRESSION"
    case click = "CLICK"
    case close = "CLOSE"
    case dismissToday = "DISMISS_TODAY"
    case function = "FUNCTION"
    case conversion = "CONVERSION"
}

struct InappMessageRenderEvent {
    let type: InappMessageRenderEventType
    let component: String
    let action: String
    let value: String
    let date: Date

    init(type: InappMessageRenderEventType, component: String, action: String = "", value: String = "", date: Date = Date()) {
        self.type = type
        self.component = component
        self.action = action
        self.value = value
        self.date = date
    }

    var logLine: String {
        var parts = ["[\(Self.timeFormatter.string(from: date))]", type.rawValue, component]
        if !action.isEmpty {
            parts.append(action)
        }
        if !value.isEmpty {
            parts.append(value)
        }
        return parts.joined(separator: " | ")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

@MainActor
struct InappMessageRenderEnvironment {
    var debugGuidesEnabled: Bool
    private let actionDispatcher: InappMessageActionDispatcher

    init(
        debugGuidesEnabled: Bool = false,
        actionDispatcher: InappMessageActionDispatcher
    ) {
        self.debugGuidesEnabled = debugGuidesEnabled
        self.actionDispatcher = actionDispatcher
    }

    func emit(_ event: InappMessageRenderEvent) {
        actionDispatcher.emit(event)
    }

    func handle(button: InappMessageRenderSpec.Button, index: Int) {
        actionDispatcher.route(button: button, index: index)
    }

    func handle(image item: InappMessageRenderSpec.Image.Item, index: Int) {
        actionDispatcher.route(image: item, index: index)
    }

    func handleCloseButton() {
        actionDispatcher.routeCloseButton()
    }

    func handleDimTap() {
        actionDispatcher.routeDimTap()
    }
}
