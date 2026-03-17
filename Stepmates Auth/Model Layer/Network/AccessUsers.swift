//
//  AccessUsers.swift
//  Stepmates Auth
//
//  Created by Диана on 30/01/2026.
//

struct AccessUsers: Codable {
    var id: Int
    var username: String
    var email: String
    var firstName: String
    var lastName: String
    var isFriend: Bool
    var requestSent: Bool
    var requestReceived: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case isFriend = "is_friend"
        case requestSent = "request_sent"
        case requestReceived = "request_received"
    }
}
