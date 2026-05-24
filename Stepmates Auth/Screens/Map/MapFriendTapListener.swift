//
//  MapFriendTapListener.swift
//  Stepmates Auth
//
//  Created by Диана on 29/04/2026.
//

import Foundation
import YandexMapsMobile

final class MapFriendTapListener: NSObject, YMKMapObjectTapListener {
    let onTap: (FriendLiveLocation) -> Void

    init(onTap: @escaping (FriendLiveLocation) -> Void) {
        self.onTap = onTap
        super.init()
    }

    func onMapObjectTap(with mapObject: YMKMapObject, point: YMKPoint) -> Bool {
        guard let friend = mapObject.userData as? FriendLiveLocation else { return false }
        onTap(friend)
        return true
    }
}
