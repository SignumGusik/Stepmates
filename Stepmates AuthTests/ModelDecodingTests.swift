import XCTest
@testable import Stepmates_Auth

final class ModelDecodingTests: XCTestCase {
    func testProfileDecodesSnakeCaseFieldsAndAchievementPresentation() throws {
        let data = #"""
        {
          "id": 1,
          "username": "diana",
          "email": "diana@example.com",
          "first_name": "Diana",
          "last_name": "S",
          "avatar_url": "https://example.com/a.jpg",
          "daily_goal_steps": 12000,
          "current_streak_days": 7,
          "total_steps": 200000,
          "friends_count": 3,
          "friends_preview": [
            {"id": 2, "username": "sister", "avatar_url": null}
          ],
          "achievements": [
            {"code": "streaks_7", "title": "Seven", "current": 7, "target": 7, "progress": 1.0, "is_finished": true},
            {"code": "custom", "title": "Custom", "current": 1, "target": 3, "progress": 0.33, "is_finished": false}
          ]
        }
        """#.data(using: .utf8)!

        let profile = try JSONDecoder().decode(MyProfileDTO.self, from: data)

        XCTAssertEqual(profile.dailyGoalSteps, 12000)
        XCTAssertEqual(profile.currentStreakDays, 7)
        XCTAssertEqual(profile.friendsPreview.first?.username, "sister")
        XCTAssertEqual(profile.achievements[0].shortTitle, "7 дней")
        XCTAssertEqual(profile.achievements[0].shortSubtitle, "стрейк подряд")
        XCTAssertEqual(profile.achievements[0].imageName, "streaks_7_complete")
        XCTAssertEqual(profile.achievements[1].shortTitle, "Custom")
        XCTAssertEqual(profile.achievements[1].imageName, "custom_finished")
    }

    func testLeaderboardAndStepsModelsDecodeBackendShape() throws {
        let leaderboard = try JSONDecoder().decode(FriendLeaderboardResponse.self, from: #"""
        {"place": 2, "user_id": 5, "username": "masha", "steps": 9800, "is_me": false, "avatar_url": null}
        """#.data(using: .utf8)!)
        let steps = try JSONDecoder().decode(SyncTodayStepsResponse.self, from: #"""
        {"id": 1, "username": "diana", "date": "2026-05-28", "steps": 10000, "goal_steps": 10000, "is_goal_completed": true}
        """#.data(using: .utf8)!)
        let goal = try JSONDecoder().decode(DailyGoalResponse.self, from: #"""
        {"daily_goal_steps": 15000, "today_steps": 7000, "is_goal_completed": false}
        """#.data(using: .utf8)!)

        XCTAssertEqual(leaderboard.userId, 5)
        XCTAssertEqual(leaderboard.avatarUrl, nil)
        XCTAssertEqual(steps.goalSteps, 10000)
        XCTAssertEqual(steps.isGoalCompleted, true)
        XCTAssertEqual(goal.dailyGoalSteps, 15000)
        XCTAssertEqual(goal.todaySteps, 7000)
    }

    func testGroupAndPasswordModelsDecodeExpectedPayloads() throws {
        let group = try JSONDecoder().decode(MapGroupDTO.self, from: #"""
        {"id": 9, "name": "Family", "avatar_url": null, "members_count": 4, "my_place": 1, "goal_steps": 70000}
        """#.data(using: .utf8)!)
        let verification = try JSONDecoder().decode(RegisterVerifyResponseDTO.self, from: #"""
        {"detail": "ok", "access": "access", "refresh": "refresh", "user": {"id": 1, "email": "diana@example.com", "username": "diana"}}
        """#.data(using: .utf8)!)
        let detail = try JSONDecoder().decode(DetailResponseDTO.self, from: #"""
        {"detail": "sent"}
        """#.data(using: .utf8)!)

        XCTAssertEqual(group.membersCount, 4)
        XCTAssertEqual(group.myPlace, 1)
        XCTAssertEqual(group.goalSteps, 70000)
        XCTAssertEqual(verification.user.email, "diana@example.com")
        XCTAssertEqual(detail.detail, "sent")
    }
}
