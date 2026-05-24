//
//  MapViewModel.swift
//  Stepmates Auth
//
//  Created by Диана on 09/05/2026.
//

import Foundation
import Combine

@MainActor
final class MapViewModel {

    @Published private(set) var groups: [MapGroupDTO] = []
    @Published private(set) var selectedScope: MapScope = .allFriends
    @Published private(set) var visibleUsers: [FriendLiveLocation] = []
    @Published private(set) var visibleTracks: [FriendMatchedTrackResponse] = []
    @Published private(set) var ranking: MapRankingDTO?

    private let mapService: MapService

    init(mapService: MapService) {
        self.mapService = mapService
    }

    func selectAllFriends() {
        selectedScope = .allFriends
    }

    func selectGroup(_ group: MapGroupDTO) {
        selectedScope = .group(id: group.id, name: group.name)
    }

    func loadInitialData() async {
        await loadGroups()
        await reloadScopeData()
    }

    func reloadScopeData() async {
        await loadVisibleUsers()
        await loadVisibleTracks()
        await loadRankingCard()
    }

    func loadGroups() async {
        do {
            groups = try await mapService.fetchMapGroups()
        } catch {
            print("Map groups fetch error:", error.localizedDescription)
        }
    }

    private func loadVisibleUsers() async {
        do {
            switch selectedScope {
            case .allFriends:
                visibleUsers = try await mapService.fetchFriendsLiveLocations()

            case .group(let id, _):
                visibleUsers = try await mapService.fetchGroupLiveLocations(groupId: id)
            }
        } catch {
            print("Visible users fetch error:", error.localizedDescription)
        }
    }

    private func loadVisibleTracks() async {
        do {
            switch selectedScope {
            case .allFriends:
                visibleTracks = try await mapService.fetchFriendsMatchedTracks()

            case .group(let id, _):
                visibleTracks = try await mapService.fetchGroupMatchedTracks(groupId: id)
            }
        } catch {
            print("Visible tracks fetch error:", error.localizedDescription)
        }
    }

    private func loadRankingCard() async {
        do {
            switch selectedScope {
            case .allFriends:
                ranking = try await mapService.fetchFriendsMapRanking()

            case .group(let id, _):
                ranking = try await mapService.fetchGroupMapRanking(groupId: id)
            }
        } catch {
            print("Ranking fetch error:", error.localizedDescription)
        }
    }
}
