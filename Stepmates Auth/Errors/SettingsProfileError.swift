//
//  SettingsProfileError.swift
//  Stepmates Auth
//
//  Created by Диана on 10/05/2026.
//

import Foundation

enum SettingsProfileError: LocalizedError {
    case emptyUsername

    var errorDescription: String? {
        switch self {
        case .emptyUsername:
            return "Введите ник."
        }
    }
}
