//
//  LogUtil.swift
//  AppBoxSnsLoginSDK
//
//  Created by mobilePartners on 1/24/25.
//

import Foundation

func debugLog(_ message: String,
                       functionName: String = #function,
                       fileName: String = #file,
                       lineNumber: Int = #line) {
    
    let formattedMessage = "[AppBoxSnsLoginSDK] \(functionName) - \(message)"
    print(formattedMessage)
}

