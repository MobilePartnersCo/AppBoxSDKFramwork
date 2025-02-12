// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@objc(AppBoxHealth)
public class AppBoxHealth: NSObject {
    @objc public static let shared: AppBoxHealthProtocol = AppBoxHealthRepository.shared
}
