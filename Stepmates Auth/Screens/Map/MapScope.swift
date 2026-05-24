//
//  MapScope.swift
//  Stepmates Auth
//
//  Created by Диана on 09/05/2026.
//

import Foundation

enum MapScope: Equatable {
    case allFriends
    case group(id: Int, name: String)
}
