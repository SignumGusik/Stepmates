//
//  AccessToken.swift
//  Stepmates Auth
//
//  Created by Диана on 27/01/2026.
//

import Foundation

struct AccessToken: Codable {
    var accessToken: String
    var refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access"
        case refreshToken = "refresh"
        
    }
}
