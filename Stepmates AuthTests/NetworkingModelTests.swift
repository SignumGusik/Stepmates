import Foundation
import XCTest
@testable import Stepmates_Auth

final class NetworkingModelTests: XCTestCase {
    private func normalizedPath(_ url: URL?) -> String? {
        guard let path = url?.path else { return nil }
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "/" + trimmed
    }

    func testImportantRoutesBuildExpectedUrls() {
        XCTAssertEqual(normalizedPath(NetworkRoutes.accessToken.url), "/api/auth/token")
        XCTAssertEqual(normalizedPath(NetworkRoutes.refreshToken.url), "/api/auth/token/refresh")
        XCTAssertEqual(normalizedPath(NetworkRoutes.groupLeaderboard(groupId: 42, period: "week").url), "/api/groups/42/leaderboard")
        XCTAssertEqual(NetworkRoutes.groupLeaderboard(groupId: 42, period: "week").url?.query, "period=week")
        XCTAssertEqual(normalizedPath(NetworkRoutes.mapGroupRanking(groupId: 7).url), "/api/map/groups/7/ranking")
    }

    func testRouteHttpMethodsMatchBackendContract() {
        XCTAssertEqual(NetworkRoutes.accessToken.method, .post)
        XCTAssertEqual(NetworkRoutes.myTodaySteps.method, .get)
        XCTAssertEqual(NetworkRoutes.updateDailyGoal.method, .patch)
        XCTAssertEqual(NetworkRoutes.profileAvatar.method, .put)
        XCTAssertEqual(NetworkRoutes.deleteProfileAvatar.method, .delete)
        XCTAssertEqual(NetworkRoutes.uploadTrackPoints.method, .post)
    }

    func testEncodableDictionaryUsesCodingKeys() throws {
        let payload = TrackPointPayload(
            latitude: 55.751,
            longitude: 37.618,
            horizontalAccuracy: 9,
            speed: 1.5,
            course: 180,
            movementState: "walking",
            stepsDelta: 24,
            confidenceScore: 94,
            movementKind: "walking",
            breakReason: nil,
            recordedAt: "2026-05-28T10:00:00Z"
        )

        let dict = try payload.asDictionary()

        XCTAssertEqual(dict["latitude"] as? Double, 55.751)
        XCTAssertEqual(dict["longitude"] as? Double, 37.618)
        XCTAssertEqual(dict["horizontal_accuracy"] as? Double, 9)
        XCTAssertEqual(dict["movement_state"] as? String, "walking")
        XCTAssertEqual(dict["steps_delta"] as? Int, 24)
        XCTAssertEqual(dict["confidence_score"] as? Int, 94)
        XCTAssertEqual(dict["movement_kind"] as? String, "walking")
        XCTAssertNil(dict["break_reason"] as? String)
    }

    func testFriendLiveLocationDecodesSnakeCaseResponse() throws {
        let json = #"""
        {
          "user_id": 9,
          "username": "diana",
          "avatar_url": null,
          "latitude": 55.75,
          "longitude": 37.61,
          "updated_at": "2026-05-28T10:00:00Z",
          "is_me": true,
          "horizontal_accuracy": 12.5,
          "confidence_score": 88,
          "movement_state": "walking",
          "movement_kind": "walking",
          "signal_quality": "good"
        }
        """#.data(using: .utf8)!

        let value = try JSONDecoder().decode(FriendLiveLocation.self, from: json)

        XCTAssertEqual(value.userId, 9)
        XCTAssertEqual(value.username, "diana")
        XCTAssertTrue(value.isMe)
        XCTAssertEqual(value.horizontalAccuracy, 12.5)
        XCTAssertEqual(value.confidenceScore, 88)
        XCTAssertEqual(value.movementKind, "walking")
        XCTAssertEqual(value.signalQuality, "good")
    }

    func testMatchedTrackSegmentDecodesDisplayPoints() throws {
        let json = #"""
        {
          "started_at": "2026-05-28T10:00:00Z",
          "ended_at": "2026-05-28T10:05:00Z",
          "status": "matched",
          "signal_quality": "good",
          "matching_confidence": "high",
          "confidence_score": 91,
          "movement_state": "walking",
          "movement_kind": "walking",
          "break_reason": null,
          "display_points": [
            {"latitude": 55.75, "longitude": 37.61, "confidence_score": 91, "movement_kind": "walking", "break_reason": null}
          ]
        }
        """#.data(using: .utf8)!

        let value = try JSONDecoder().decode(MatchedTrackSegmentResponse.self, from: json)

        XCTAssertEqual(value.status, "matched")
        XCTAssertEqual(value.signalQuality, "good")
        XCTAssertEqual(value.matchingConfidence, "high")
        XCTAssertEqual(value.confidenceScore, 91)
        XCTAssertEqual(value.displayPoints.count, 1)
        XCTAssertEqual(value.displayPoints[0].movementKind, "walking")
    }
}
