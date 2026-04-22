import Foundation
import WebKit
@_spi(AppBoxInternal) import AppBoxCoreSDK

public struct WebViewRuntimeConfig {
    public let configuration: WKWebViewConfiguration
    public let allowsBackForwardNavigationGestures: Bool
    public let scrollContentSize: CGSize
    public let scrollContentOffset: CGPoint
    public let scrollContentInset: UIEdgeInsets
    public let isScrollEnabled: Bool
    public let scrollBounces: Bool
    public let scrollAlwaysBounceVertical: Bool
    public let scrollAlwaysBounceHorizontal: Bool
    public let showsHorizontalScrollIndicator: Bool
    public let showsVerticalScrollIndicator: Bool

    public init(
        configuration: WKWebViewConfiguration,
        allowsBackForwardNavigationGestures: Bool,
        scrollContentSize: CGSize,
        scrollContentOffset: CGPoint,
        scrollContentInset: UIEdgeInsets,
        isScrollEnabled: Bool,
        scrollBounces: Bool,
        scrollAlwaysBounceVertical: Bool,
        scrollAlwaysBounceHorizontal: Bool,
        showsHorizontalScrollIndicator: Bool,
        showsVerticalScrollIndicator: Bool
    ) {
        self.configuration = configuration
        self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        self.scrollContentSize = scrollContentSize
        self.scrollContentOffset = scrollContentOffset
        self.scrollContentInset = scrollContentInset
        self.isScrollEnabled = isScrollEnabled
        self.scrollBounces = scrollBounces
        self.scrollAlwaysBounceVertical = scrollAlwaysBounceVertical
        self.scrollAlwaysBounceHorizontal = scrollAlwaysBounceHorizontal
        self.showsHorizontalScrollIndicator = showsHorizontalScrollIndicator
        self.showsVerticalScrollIndicator = showsVerticalScrollIndicator
    }
}

public final class WebViewConfigStore {
    public init() {}

    public func makeRuntimeConfig(from provider: WebConfigProvider) -> WebViewRuntimeConfig {
        let configuration = Self.decodeConfiguration(from: provider.customWebViewConfigurationData) ?? Self.makeDefaultConfiguration()

        return WebViewRuntimeConfig(
            configuration: configuration,
            allowsBackForwardNavigationGestures: provider.allowsBackForwardNavigationGestures,
            scrollContentSize: provider.scrollContentSize,
            scrollContentOffset: provider.scrollContentOffset,
            scrollContentInset: UIEdgeInsets(
                top: provider.scrollContentInset.top,
                left: provider.scrollContentInset.left,
                bottom: provider.scrollContentInset.bottom,
                right: provider.scrollContentInset.right
            ),
            isScrollEnabled: provider.isScrollEnabled,
            scrollBounces: provider.scrollBounces,
            scrollAlwaysBounceVertical: provider.scrollAlwaysBounceVertical,
            scrollAlwaysBounceHorizontal: provider.scrollAlwaysBounceHorizontal,
            showsHorizontalScrollIndicator: provider.showsHorizontalScrollIndicator,
            showsVerticalScrollIndicator: provider.showsVerticalScrollIndicator
        )
    }

    private static func decodeConfiguration(from data: Data?) -> WKWebViewConfiguration? {
        guard let data = data else {
            return nil
        }

        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: WKWebViewConfiguration.self,
            from: data
        )
    }

    private static func makeDefaultConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()
        configuration.websiteDataStore = .default()
        if #available(iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            configuration.preferences.javaScriptEnabled = true
        }
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio]
        return configuration
    }
}
