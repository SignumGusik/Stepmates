//
//  KeyChainError.swift
//  Stepmates Auth
//
//  Created by Диана on 27/01/2026.
//

import Foundation

enum KeyChainError: Error {
    case saveFailed
    case retrieveFailed
    case deleteFailed
}
