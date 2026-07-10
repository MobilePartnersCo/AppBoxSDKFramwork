import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

@MainActor
final class InappMessageActionDispatcher {
    var openLinks: Bool
    var onRequestClose: (String) -> Void

    private let onEvent: (InappMessageRenderEvent) -> Void
    private let onEventBatch: ([InappMessageRenderEvent]) -> Void
    private let onDismissToday: (InappMessageRenderEvent) -> Void
    private let onEventAction: (String) -> Void

    init(
        openLinks: Bool = false,
        onEvent: @escaping (InappMessageRenderEvent) -> Void,
        onEventBatch: @escaping ([InappMessageRenderEvent]) -> Void = { _ in },
        onDismissToday: @escaping (InappMessageRenderEvent) -> Void = { _ in },
        onEventAction: @escaping (String) -> Void = { _ in },
        onRequestClose: @escaping (String) -> Void = { _ in }
    ) {
        self.openLinks = openLinks
        self.onEvent = onEvent
        self.onEventBatch = onEventBatch
        self.onDismissToday = onDismissToday
        self.onEventAction = onEventAction
        self.onRequestClose = onRequestClose
    }

    func emit(_ event: InappMessageRenderEvent) {
        onEvent(event)
        onEventBatch([event])
    }

    func route(button: InappMessageRenderSpec.Button, index: Int) {
        let component = "BUTTON\(index + 1)"
        let clickEvent = InappMessageRenderEvent(
            type: .click,
            component: component,
            action: button.action.rawValue,
            value: button.actionValue
        )
        var events = [InappMessageRenderEvent]()
        var eventActionValue: String?

        switch button.action {
        case .link, .external:
            events.append(clickEvent)
            openURLIfNeeded(button.actionValue)
        case .dismissToday:
            events.append(clickEvent)
            let event = InappMessageRenderEvent(
                type: .dismissToday,
                component: component,
                action: button.action.rawValue,
                value: button.actionValue
            )
            events.append(event)
            onDismissToday(event)
        case .function:
            events.append(clickEvent)
            eventActionValue = nonEmptyActionValue(button.actionValue)
        case .event:
            events.append(clickEvent)
            eventActionValue = nonEmptyActionValue(button.actionValue)
        case .close:
            events.append(clickEvent)
        case .none:
            events.append(clickEvent)
        case .conversion:
            events.append(clickEvent)
            events.append(InappMessageRenderEvent(type: .conversion, component: component, action: button.action.rawValue, value: button.actionValue))
        }

        switch button.action {
        case .close, .dismissToday:
            events.append(closeEvent(component: component, action: button.action.rawValue))
        case .link, .external, .function, .event, .none, .conversion:
            break
        }

        emitBatch(events)
        if let eventActionValue {
            onEventAction(eventActionValue)
        }

        guard button.action != .conversion else { return }
        onRequestClose("button-\(button.action.rawValue)")
    }

    func route(image item: InappMessageRenderSpec.Image.Item, index: Int) {
        _ = index
        let component = "IMAGE"
        var events = [InappMessageRenderEvent]()
        let clickEvent = InappMessageRenderEvent(
            type: .click,
            component: component,
            action: item.action.rawValue,
            value: item.actionValue
        )
        var eventActionValue: String?

        switch item.action {
        case .none:
            break
        case .close:
            events.append(clickEvent)
        case .dismissToday:
            events.append(clickEvent)
            let event = InappMessageRenderEvent(
                type: .dismissToday,
                component: component,
                action: item.action.rawValue,
                value: item.actionValue
            )
            events.append(event)
            onDismissToday(event)
        case .link, .external:
            events.append(clickEvent)
            openURLIfNeeded(item.actionValue)
        case .function:
            events.append(clickEvent)
            eventActionValue = nonEmptyActionValue(item.actionValue)
        case .event:
            events.append(clickEvent)
            eventActionValue = nonEmptyActionValue(item.actionValue)
        case .conversion:
            events.append(clickEvent)
            events.append(InappMessageRenderEvent(type: .conversion, component: component, action: item.action.rawValue, value: item.actionValue))
        }

        switch item.action {
        case .close, .dismissToday:
            events.append(closeEvent(component: component, action: item.action.rawValue))
        case .link, .external, .function, .event, .none, .conversion:
            break
        }

        guard !events.isEmpty else { return }

        emitBatch(events)
        if let eventActionValue {
            onEventAction(eventActionValue)
        }

        switch item.action {
        case .close, .dismissToday:
            onRequestClose("image-\(item.action.rawValue)")
        case .link, .external:
            onRequestClose("image")
        case .function, .event:
            onRequestClose("image-\(item.action.rawValue)")
        case .none, .conversion:
            break
        }
    }

    func routeCloseButton() {
        routeClose(component: "CLOSE_X", action: "close", reason: "close-button")
    }

    func routeDimTap() {
        routeClose(component: "DIM", action: "close", reason: "dim")
    }

    func routeClose(component: String, action: String, reason: String) {
        emitBatch([
            InappMessageRenderEvent(type: .click, component: component, action: action),
            closeEvent(component: component, action: action)
        ])
        onRequestClose(reason)
    }

    private func emitBatch(_ events: [InappMessageRenderEvent]) {
        guard !events.isEmpty else { return }
        events.forEach(onEvent)
        onEventBatch(events)
    }

    private func closeEvent(component: String, action: String) -> InappMessageRenderEvent {
        InappMessageRenderEvent(type: .close, component: component, action: action)
    }

    private func nonEmptyActionValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private func openURLIfNeeded(_ urlString: String) {
        guard openLinks, let url = safeURL(from: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func safeURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized: String
        if trimmed.contains("://") {
            normalized = trimmed
        } else if trimmed.contains(".") {
            normalized = "https://\(trimmed)"
        } else {
            normalized = trimmed
        }

        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              !Self.blockedSchemes.contains(scheme) else {
            return nil
        }

        return url
    }

    private static let blockedSchemes: Set<String> = [
        "javascript",
        "data",
        "vbscript",
        "blob",
        "file",
    ]
}
