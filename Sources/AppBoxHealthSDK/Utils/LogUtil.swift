//
//  File.swift
//  
//
//  Created by mobilePartners on 2/11/25.
//

import Foundation

func debugLog(_ message: String,
                       functionName: String = #function,
                       fileName: String = #file,
                       lineNumber: Int = #line) {
    
    let formattedMessage = "[AppBoxHealthSDK] \(functionName) - \(message)"
    print(formattedMessage)
}
