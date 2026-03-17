//
//  UsernameError.swift
//  Stepmates Auth
//
//  Created by Диана on 17/03/2026.
//

import UIKit

enum UsernameError: LocalizedError {
    case missingFields
    case tooShort
    case tooLong
    case invalidFormat
    case missingAccessToken

    var errorDescription: String? {
        switch self {
        case .missingFields:
            return "Введите никнейм"
        case .tooShort:
            return "Никнейм должен содержать минимум 3 символа"
        case .tooLong:
            return "Никнейм должен содержать максимум 30 символов"
        case .invalidFormat:
            return "Никнейм может содержать только латинские буквы, цифры и _"
        case .missingAccessToken:
            return "Не удалось получить токен доступа"
        }
    }
}
