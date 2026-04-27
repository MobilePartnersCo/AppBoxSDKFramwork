import Foundation
import WebKit
@_spi(AppBoxInternal) import AppBoxCoreSDK

public protocol WebManagerDelegate: AnyObject {
    func didReceiveScriptMessage(_ message: WKScriptMessage, completion: @escaping () -> Void)
}

public final class WebManager: NSObject {
    public static var shared: WebManager?

    public weak var delegate: WebManagerDelegate?

    public let configuration: WKWebViewConfiguration
    private let userContentController: WKUserContentController
    private let runtimeConfigProvider: WebRuntimeConfigProvider

    private var messageQueue = WebQueue<WKScriptMessage>()
    private var isProcessingMessage = false
    private weak var currentWebView: WKWebView?

    public init(
        configProvider: WebConfigProvider,
        runtimeConfigProvider: WebRuntimeConfigProvider,
        configStore: WebViewConfigStore = WebViewConfigStore()
    ) {
        self.runtimeConfigProvider = runtimeConfigProvider
        self.userContentController = WKUserContentController()

        let runtimeConfig = configStore.makeRuntimeConfig(from: configProvider)
        self.configuration = runtimeConfig.configuration
        self.configuration.userContentController = userContentController

        super.init()

        installDebugScriptsIfNeeded()
        self.userContentController.add(WeakScriptMessageHandler(delegate: self), name: "appbox")
    }

    public static func initializeShared(
        configProvider: WebConfigProvider,
        runtimeConfigProvider: WebRuntimeConfigProvider,
        configStore: WebViewConfigStore = WebViewConfigStore()
    ) {
        if shared == nil {
            shared = WebManager(
                configProvider: configProvider,
                runtimeConfigProvider: runtimeConfigProvider,
                configStore: configStore
            )
        }
    }

    public static func reset() {
        shared = nil
    }

    public func setCurrentWebView(_ webView: WKWebView) {
        currentWebView = webView
    }

    public func getCurrentWebView() -> WKWebView? {
        currentWebView
    }

    public func clearCurrentWebView() {
        currentWebView = nil
    }

    private func processNextMessage() {
        if isProcessingMessage {
            return
        }

        guard let message = messageQueue.peek() else {
            return
        }

        isProcessingMessage = true
        delegate?.didReceiveScriptMessage(message) { [weak self] in
            guard let self = self else { return }
            _ = self.messageQueue.dequeue()
            self.isProcessingMessage = false
            self.processNextMessage()
        }
    }

    private func installDebugScriptsIfNeeded() {
        if runtimeConfigProvider.debugMode == .demo {
            let script = """
            var sdk = document.createElement('script');
            sdk.src="https://consoledev.appboxapp.com/import/appbox.v3.js";
            document.head.appendChild(sdk);
            """
            userContentController.addUserScript(
                WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }

        let mode = runtimeConfigProvider.debugMode
        if mode == .dev || mode == .demo {
            let erudaScript = """
            (function() {
                var script = document.createElement('script');
                script.src = 'https://cdn.jsdelivr.net/npm/eruda';
                script.onload = function() {
                    eruda.init({ defaults: { displaySize: 60 } });
                    eruda.get('console').config.set('jsExecution', false);
                    eruda._entryBtn.hide();
                };
                document.head.appendChild(script);
            })();
            """
            userContentController.addUserScript(
                WKUserScript(source: erudaScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }
    }
}

extension WebManager: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        messageQueue.enqueue(message)
        processNextMessage()
    }
}
