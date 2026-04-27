import Foundation
import WebKit

public enum BridgeBlockReason {
    case none
    case duplicateAction
    case presentationBusy
    case bottomInterfaceBusy
}

public protocol BridgeMessageHandler: AnyObject {
    func handle(
        messageBody: [String: Any],
        webView: WKWebView,
        action: String,
        callId: String?
    )
}

public protocol BridgeMessageHandlerRegistry: AnyObject {
    func handler(for action: String) -> BridgeMessageHandler?
}

public extension BridgeMessageHandlerRegistry {
    func handler(for action: String, callId: String?) -> BridgeMessageHandler? {
        handler(for: action)
    }
}

public struct BridgeActionPolicy {
    public let presentationActions: Set<String>
    public let bottomInterfaceActions: Set<String>

    public init(
        presentationActions: Set<String> = [],
        bottomInterfaceActions: Set<String> = []
    ) {
        self.presentationActions = presentationActions
        self.bottomInterfaceActions = bottomInterfaceActions
    }

    public static let appBoxDefault = BridgeActionPolicy(
        presentationActions: [
            "application.biometricAuth",
            "application.share",
            "application.updatePrompt",
            "application.snsLogin",
            "application.loadingShow",
            "message.inAppOpen",
            "phone.getContacts",
            "scanner.openQRCodeScanner",
            "scanner.openBarcodeScanner",
            "ui.calendarOpen",
            "ui.fullPopupOpen",
            "ui.centerPopupOpen",
            "ui.bottomSheetPopupOpen",
            "ui.imageViewerOpen",
            "ui.barcodePopupOpen",
            "ui.qrcodePopupOpen",
            "ui.modalPageOpen",
            "ui.pdfViewerOpen"
        ],
        bottomInterfaceActions: [
            "gmenu.openTabsMenu",
            "gmenu.closeTabsMenu",
            "gmenu.openBrowserMenu",
            "gmenu.closeBrowserMenu"
        ]
    )
}

public final class BridgeRuntime {
    private var processingActions: Set<String> = []
    private var callIdActionMap: [String: String] = [:]
    private var activePresentationCallId: String?
    private var activeBottomInterfaceCallId: String?
    private var timeoutWorkItems: [String: DispatchWorkItem] = [:]
    private var completionObservers: [String: () -> Void] = [:]

    private let lockTimeout: TimeInterval
    private let bottomInterfaceUnlockDelay: TimeInterval
    private let presentationActions: Set<String>
    private let bottomInterfaceActions: Set<String>

    public init(
        policy: BridgeActionPolicy = BridgeActionPolicy(),
        lockTimeout: TimeInterval = 30,
        bottomInterfaceUnlockDelay: TimeInterval = 0.35
    ) {
        self.presentationActions = policy.presentationActions
        self.bottomInterfaceActions = policy.bottomInterfaceActions
        self.lockTimeout = lockTimeout
        self.bottomInterfaceUnlockDelay = bottomInterfaceUnlockDelay
    }

    public func resolvedHandler(
        for action: String,
        callId: String?,
        registry: BridgeMessageHandlerRegistry
    ) -> BridgeMessageHandler? {
        assert(Thread.isMainThread, "BridgeRuntime.resolvedHandler는 메인 스레드에서 호출해야 합니다.")

        guard let handler = registry.handler(for: action, callId: callId) else {
            return nil
        }

        lock(action: action, callId: callId)
        return handler
    }

    public func blockReason(for action: String, callId: String?) -> BridgeBlockReason {
        guard callId != nil else { return .none }

        if isProcessing(action: action) {
            return .duplicateAction
        }

        if presentationActions.contains(action), activePresentationCallId != nil {
            return .presentationBusy
        }

        if bottomInterfaceActions.contains(action), activeBottomInterfaceCallId != nil {
            return .bottomInterfaceBusy
        }

        return .none
    }

    public func registerCompletionObserver(callId: String, observer: @escaping () -> Void) {
        assert(Thread.isMainThread, "BridgeRuntime.registerCompletionObserver는 메인 스레드에서 호출해야 합니다.")
        completionObservers[callId] = observer
    }

    public func lock(action: String, callId: String?) {
        assert(Thread.isMainThread, "BridgeRuntime.lock은 메인 스레드에서 호출해야 합니다.")
        guard let callId = callId else { return }

        let isPresentationAction = presentationActions.contains(action)
        let isBottomInterfaceAction = bottomInterfaceActions.contains(action)

        if isPresentationAction || isBottomInterfaceAction {
            processingActions.insert(action)
            callIdActionMap[callId] = action
        }
        if isPresentationAction {
            activePresentationCallId = callId
        }
        if isBottomInterfaceAction {
            activeBottomInterfaceCallId = callId
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.forceUnlock(callId: callId)
        }
        timeoutWorkItems[callId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + lockTimeout, execute: workItem)
    }

    public func complete(callId: String?) {
        assert(Thread.isMainThread, "BridgeRuntime.complete는 메인 스레드에서 호출해야 합니다.")
        guard let callId = callId else { return }

        completionObservers.removeValue(forKey: callId)?()
        timeoutWorkItems.removeValue(forKey: callId)?.cancel()

        if activePresentationCallId == callId {
            activePresentationCallId = nil
        }

        guard let action = callIdActionMap.removeValue(forKey: callId) else { return }

        if activeBottomInterfaceCallId == callId {
            DispatchQueue.main.asyncAfter(deadline: .now() + bottomInterfaceUnlockDelay) { [weak self] in
                guard let self = self else { return }
                if self.activeBottomInterfaceCallId == callId {
                    self.activeBottomInterfaceCallId = nil
                }
                self.processingActions.remove(action)
            }
            return
        }

        processingActions.remove(action)
    }

    private func isProcessing(action: String) -> Bool {
        (presentationActions.contains(action) || bottomInterfaceActions.contains(action)) &&
            processingActions.contains(action)
    }

    private func forceUnlock(callId: String) {
        completionObservers.removeValue(forKey: callId)?()
        timeoutWorkItems.removeValue(forKey: callId)
        if activePresentationCallId == callId {
            activePresentationCallId = nil
        }
        if activeBottomInterfaceCallId == callId {
            activeBottomInterfaceCallId = nil
        }
        if let action = callIdActionMap.removeValue(forKey: callId) {
            processingActions.remove(action)
        }
    }
}
