//
//  Encodable+Dict.swift
//  Stepmates Auth
//
//  Created by Диана on 15/03/2026.
//

import Foundation

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else {
            throw ConfigurationError.nilObject
        }
        return dict
    }
}
