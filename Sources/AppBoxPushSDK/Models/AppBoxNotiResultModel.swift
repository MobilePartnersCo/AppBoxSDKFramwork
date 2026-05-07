//
//  AppBoxNotiResultModel.swift
//  AppBoxPushSDK
//

import Foundation

@objcMembers
public final class AppBoxNotiResultModel: NSObject, Codable {
    public let token: String
    public let message: String

    enum CodingKeys: String, CodingKey {
        case token, message
    }

    public init(token: String, message: String) {
        self.token = token
        self.message = message
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.token = try container.decode(String.self, forKey: .token)
        self.message = try container.decode(String.self, forKey: .message)
    }
}
