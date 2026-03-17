//
//  PasswordReset.swift
//  Stepmates Auth
//
//  Created by Диана on 15/03/2026.
//

import Foundation

struct PasswordResetRequestDTO: Encodable {
    let email: String
}

struct PasswordResetVerifyDTO: Encodable {
    let email: String
    let code: String
}

struct PasswordResetConfirmDTO: Encodable {
    let email: String
    let code: String
    let password: String
    let password2: String
}

struct DetailResponseDTO: Decodable {
    let detail: String
}

struct ApiMessageDTO: Decodable {
    let detail: String
}

struct RegisterVerifyResponseDTO: Codable {
    let detail: String
    let access: String
    let refresh: String
    let user: VerifiedUserDTO
}

struct VerifiedUserDTO: Codable {
    let id: Int
    let email: String
    let username: String
}
