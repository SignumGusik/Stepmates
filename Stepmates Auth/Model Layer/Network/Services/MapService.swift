//
//  MapService.swift
//  Stepmates Auth
//
//  Created by Диана on 21/04/2026.
//

import Foundation
import YandexMapsMobile

struct EmptyResponse: Decodable {}

final class MapService {
    private let networkHandler: NetworkHandler
    private let tokenStorage: AccessTokenStorage
    private let isoFormatter = ISO8601DateFormatter()

    init(networkHandler: NetworkHandler, tokenStorage: AccessTokenStorage) {
        self.networkHandler = networkHandler
        self.tokenStorage = tokenStorage
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func updateLiveLocation(
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        speed: Double?,
        course: Double?,
        confidenceScore: Int? = nil,
        movementState: String? = nil,
        isSharing: Bool = true
    ) async throws {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.updateLiveLocation.url else {
            throw ConfigurationError.nilObject
        }

        var body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "horizontal_accuracy": horizontalAccuracy,
            "is_sharing": isSharing
        ]
        
        body["speed"] = speed ?? NSNull()
        body["course"] = course ?? NSNull()
        if let confidenceScore {
            body["confidence_score"] = confidenceScore
        }
        if let movementState {
            body["movement_state"] = movementState
        }

        _ = try await networkHandler.request(
            url,
            jsonDictionary: body,
            responseType: EmptyResponse.self,
            httpMethod: NetworkRoutes.updateLiveLocation.method.rawValue,
            accessToken: token.accessToken
        ) as EmptyResponse
    }

    func uploadTrackPoints(_ points: [TrackPointPayload]) async throws {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.uploadTrackPoints.url else {
            throw ConfigurationError.nilObject
        }

        let body: [String: Any] = [
            "points": points.map { jsonPayload(for: $0) }
        ]

        _ = try await networkHandler.request(
            url,
            jsonDictionary: body,
            responseType: EmptyResponse.self,
            httpMethod: NetworkRoutes.uploadTrackPoints.method.rawValue,
            accessToken: token.accessToken
        ) as EmptyResponse
    }

    func fetchMyMatchedTrack() async throws -> [TrackSegment] {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.myMatchedTrack.url else {
            throw ConfigurationError.nilObject
        }

        let items: [MatchedTrackSegmentResponse] = try await networkHandler.request(
            url,
            responseType: [MatchedTrackSegmentResponse].self,
            httpMethod: NetworkRoutes.myMatchedTrack.method.rawValue,
            accessToken: token.accessToken
        )

        return items.compactMap { item in
            guard let startedAt = isoFormatter.date(from: item.startedAt),
                  let endedAt = isoFormatter.date(from: item.endedAt) else {
                return nil
            }

            let quality = trackQuality(from: item.signalQuality)
            let points = item.displayPoints.map {
                YMKPoint(latitude: $0.latitude, longitude: $0.longitude)
            }

            guard points.count >= 2 else { return nil }

            return TrackSegment(
                points: points,
                quality: quality,
                startedAt: startedAt,
                endedAt: endedAt,
                confidenceScore: item.confidenceScore,
                movementKind: mapMovementKind(from: item.movementKind ?? item.movementState),
                breakReason: trackBreakReason(from: item.breakReason)
            )
        }
    }

    func fetchFriendsLiveLocations() async throws -> [FriendLiveLocation] {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.friendsLiveLocation.url else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            responseType: [FriendLiveLocation].self,
            httpMethod: NetworkRoutes.friendsLiveLocation.method.rawValue,
            accessToken: token.accessToken
        )
    }

    func fetchMyProfile() async throws -> MyProfileDTO {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.myProfile.url else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            responseType: MyProfileDTO.self,
            httpMethod: NetworkRoutes.myProfile.method.rawValue,
            accessToken: token.accessToken
        )
    }

    func fetchFriendsMatchedTracks() async throws -> [FriendMatchedTrackResponse] {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.friendsMatchedTracks.url else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            responseType: [FriendMatchedTrackResponse].self,
            httpMethod: NetworkRoutes.friendsMatchedTracks.method.rawValue,
            accessToken: token.accessToken
        )
    }
    
    func fetchMapGroups() async throws -> [MapGroupDTO] {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.mapGroups.url else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            responseType: [MapGroupDTO].self,
            httpMethod: NetworkRoutes.mapGroups.method.rawValue,
            accessToken: token.accessToken
        )
    }

    func fetchGroupLiveLocations(groupId: Int) async throws -> [FriendLiveLocation] {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.groupLiveLocations(groupId: groupId).url else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            responseType: [FriendLiveLocation].self,
            httpMethod: NetworkRoutes.groupLiveLocations(groupId: groupId).method.rawValue,
            accessToken: token.accessToken
        )
    }

    func fetchGroupMatchedTracks(groupId: Int) async throws -> [FriendMatchedTrackResponse] {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.groupMatchedTracks(groupId: groupId).url else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            responseType: [FriendMatchedTrackResponse].self,
            httpMethod: NetworkRoutes.groupMatchedTracks(groupId: groupId).method.rawValue,
            accessToken: token.accessToken
        )
    }

    func fetchFriendsMapRanking() async throws -> MapRankingDTO {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.mapFriendsRanking.url else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            responseType: MapRankingDTO.self,
            httpMethod: NetworkRoutes.mapFriendsRanking.method.rawValue,
            accessToken: token.accessToken
        )
    }

    func fetchGroupMapRanking(groupId: Int) async throws -> MapRankingDTO {
        guard let token = tokenStorage.get() else {
            throw NSError(domain: "auth", code: 401)
        }

        guard let url = NetworkRoutes.mapGroupRanking(groupId: groupId).url else {
            throw ConfigurationError.nilObject
        }

        return try await networkHandler.request(
            url,
            responseType: MapRankingDTO.self,
            httpMethod: NetworkRoutes.mapGroupRanking(groupId: groupId).method.rawValue,
            accessToken: token.accessToken
        )
    }
}

private extension MapService {
    func trackQuality(from signalQuality: String?) -> TrackQuality {
        switch signalQuality {
        case "good":
            return .good
        case "weak":
            return .weak
        case "poor":
            return .poor
        default:
            return .weak
        }
    }
    
    func mapMovementKind(from rawValue: String?) -> MapMovementKind {
        guard let rawValue else { return .unknown }
        
        switch rawValue {
        case "walking", "running":
            return .walking
        case "automotive", "cycling", "transport":
            return .transport
        case "stationary":
            return .stationary
        case "signal_lost":
            return .signalLost
        default:
            return MapMovementKind(rawValue: rawValue) ?? .unknown
        }
    }
    
    func trackBreakReason(from rawValue: String?) -> TrackBreakReason? {
        guard let rawValue else { return nil }
        return TrackBreakReason(rawValue: rawValue)
    }
    
    func jsonPayload(for point: TrackPointPayload) -> [String: Any] {
        var payload: [String: Any] = [
            "latitude": point.latitude,
            "longitude": point.longitude,
            "recorded_at": point.recordedAt
        ]
        
        payload["horizontal_accuracy"] = point.horizontalAccuracy ?? NSNull()
        payload["speed"] = point.speed ?? NSNull()
        payload["course"] = point.course ?? NSNull()
        payload["movement_state"] = point.movementState ?? NSNull()
        payload["steps_delta"] = point.stepsDelta ?? NSNull()
        payload["confidence_score"] = point.confidenceScore ?? NSNull()
        payload["movement_kind"] = point.movementKind ?? NSNull()
        payload["break_reason"] = point.breakReason ?? NSNull()
        
        return payload
    }
}
