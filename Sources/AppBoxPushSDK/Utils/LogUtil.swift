//
//  LogUtil.swift
//  appboxpush
//
//  Created by mobilePartners on 2/3/25.
//

import Foundation

func debugLog(_ message: String,
                       functionName: String = #function,
                       fileName: String = #file,
                       lineNumber: Int = #line) {
    
    let formattedMessage = "[AppBoxPushSDK] \(functionName) - \(message)"
    print(formattedMessage)
}
