import Foundation
import XCTest
@testable import Stepmates_Auth

final class RouteCatalogTests: XCTestCase {
    private func normalizedPath(_ route: NetworkRoutes) -> String? {
        guard let path = route.url?.path else { return nil }
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "/" + trimmed
    }

    func testEveryRouteBuildsExpectedPathAndMethod() {
        let cases: [(NetworkRoutes, String, HttpMethod)] = [
            (.register, "/api/register", .post),
            (.accessToken, "/api/auth/token", .post),
            (.refreshToken, "/api/auth/token/refresh", .post),
            (.fatchData, "/api/login_data", .get),
            (.searchUsers(query: "diana"), "/api/users", .get),
            (.createFriendRequest, "/api/friend-requests", .post),
            (.incomingFriendRequest, "/api/friend-requests/incoming", .get),
            (.outgoingFriendRequest, "/api/friend-requests/outgoing", .get),
            (.acceptFriendRequest(id: 3), "/api/friend-requests/3/accept", .post),
            (.rejectFriendRequest(id: 3), "/api/friend-requests/3/reject", .post),
            (.friendsList, "/api/friends", .get),
            (.deleteFriend(id: 5), "/api/friends/5", .delete),
            (.resetPasswordRequest, "/api/password-reset/request", .post),
            (.passwordResetRequest, "/api/password-reset", .post),
            (.passwordResetVerify, "/api/password-reset/verify", .post),
            (.passwordResetConfirm, "/api/password-reset/confirm", .post),
            (.syncTodaySteps, "/api/steps/sync", .post),
            (.myTodaySteps, "/api/steps/me/today", .get),
            (.updateDailyGoal, "/api/steps/goal", .patch),
            (.friendsLeaderboard, "/api/friends/leaderboard", .get),
            (.registerVerify, "/api/register/verify", .post),
            (.registerResend, "/api/register/resend", .post),
            (.setUsername, "/api/profile/username", .post),
            (.myProfile, "/api/profile/me", .get),
            (.profileAvatar, "/api/profile/avatar", .put),
            (.deleteProfileAvatar, "/api/profile/avatar", .delete),
            (.updateLiveLocation, "/api/map/live-location", .post),
            (.friendsLiveLocation, "/api/map/friends-live", .get),
            (.userCard(id: 8), "/api/users/8/card", .get),
            (.removeFriend(userID: 8), "/api/friends/8", .delete),
            (.cancelFriendRequest(userID: 8), "/api/friend-requests/8/cancel", .delete),
            (.uploadTrackPoints, "/api/map/track-points", .post),
            (.myTrack, "/api/map/my-track", .get),
            (.friendsTracks, "/api/map/friends-tracks", .get),
            (.myMatchedTrack, "/api/map/my-matched-track", .get),
            (.friendsMatchedTracks, "/api/map/friends-matched-tracks", .get),
            (.groups, "/api/groups", .get),
            (.createGroup, "/api/groups", .post),
            (.groupAddMember(groupId: 9), "/api/groups/9/members", .post),
            (.groupRemoveMember(groupId: 9, userId: 2), "/api/groups/9/members/2", .delete),
            (.groupPromoteAdmin(groupId: 9, userId: 2), "/api/groups/9/members/2/promote", .post),
            (.groupAvatar(groupId: 9), "/api/groups/9/avatar", .put),
            (.groupDetail(groupId: 9), "/api/groups/9", .get),
            (.groupLeaderboard(groupId: 9, period: "month"), "/api/groups/9/leaderboard", .get),
            (.groupLeave(groupId: 9), "/api/groups/9/leave", .post),
            (.updateGroup(groupId: 9), "/api/groups/9", .patch),
            (.groupDemoteAdmin(groupId: 9, userId: 2), "/api/groups/9/members/2/demote", .post),
            (.notifications, "/api/notifications", .get),
            (.acceptGroupInvite(inviteId: 4), "/api/group-invites/4/accept", .post),
            (.rejectGroupInvite(inviteId: 4), "/api/group-invites/4/reject", .post),
            (.dismissFriendAcceptedNotification(requestId: 12), "/api/notifications/friend-request-accepted/12/dismiss", .post),
            (.mapGroups, "/api/map/groups", .get),
            (.groupLiveLocations(groupId: 7), "/api/map/groups/7/live", .get),
            (.groupMatchedTracks(groupId: 7), "/api/map/groups/7/matched-tracks", .get),
            (.mapFriendsRanking, "/api/map/ranking", .get),
            (.mapGroupRanking(groupId: 7), "/api/map/groups/7/ranking", .get)
        ]

        for (route, expectedPath, expectedMethod) in cases {
            XCTAssertEqual(route.url?.scheme, "https")
            XCTAssertEqual(route.url?.host, "stepmates.onrender.com")
            XCTAssertEqual(normalizedPath(route), expectedPath)
            XCTAssertEqual(route.method, expectedMethod)
        }
    }

    func testQueryRoutesKeepExpectedQueryItems() {
        XCTAssertEqual(NetworkRoutes.searchUsers(query: "diana").url?.query, "q=diana")
        XCTAssertEqual(NetworkRoutes.groupLeaderboard(groupId: 9, period: "month").url?.query, "period=month")
        XCTAssertEqual(NetworkRoutes.myTrack.url?.query, "day=today")
        XCTAssertEqual(NetworkRoutes.friendsTracks.url?.query, "day=today")
        XCTAssertEqual(NetworkRoutes.myMatchedTrack.url?.query, "day=today")
        XCTAssertEqual(NetworkRoutes.friendsMatchedTracks.url?.query, "day=today")
    }
}
