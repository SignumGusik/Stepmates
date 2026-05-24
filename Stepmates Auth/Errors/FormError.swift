//
//  FormError.swift
//  Stepmates Auth
//
//  Created by Диана on 27/01/2026.
//

import Foundation

enum FormError: Error {
    case missingFields
    case incorrectEntries
    case passwordsDoNotMatch
}

extension FormError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingFields:
            return "Заполните все поля."
        case .incorrectEntries:
            return "Проверьте введённые данные."
        case .passwordsDoNotMatch:
            return "Пароли не совпадают."
        }
    }
}
