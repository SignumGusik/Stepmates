//
//  NetworkRoutes.swift
//  Stepmates Auth
//
//  Created by Диана on 27/01/2026.
//

import Foundation

enum NetworkRoutes {
    private static let baseUrl = "https://stepmates.onrender.com/"
    
    case register
    case accessToken
    case fatchData
    case searchUsers(query: String)
    case createFriendRequest
    case incomingFriendRequest
    case outgoingFriendRequest
    case acceptFriendRequest(id: Int)
    case rejectFriendRequest(id: Int)
    case friendsList
    case deleteFriend(id: Int)
    case resetPasswordRequest
    case passwordResetRequest
    case passwordResetVerify
    case passwordResetConfirm
    case syncTodaySteps
    case friendsLeaderboard
    case registerVerify
    case registerResend
    case setUsername
    case myProfile
    case profileAvatar
    case deleteProfileAvatar
    case updateLiveLocation
    case friendsLiveLocation
    case userCard(id: Int)
    case removeFriend(userID: Int)
    case cancelFriendRequest(userID: Int)
    case uploadTrackPoints
    case myTrack
    case friendsTracks
    case myMatchedTrack
    case friendsMatchedTracks
    case groups
    case createGroup
    case groupAddMember(groupId: Int)
    case groupRemoveMember(groupId: Int, userId: Int)
    case groupPromoteAdmin(groupId: Int, userId: Int)
    case groupAvatar(groupId: Int)
    case groupDetail(groupId: Int)
    case groupLeaderboard(groupId: Int, period: String)
    case groupLeave(groupId: Int)
    case updateGroup(groupId: Int)
    case groupDemoteAdmin(groupId: Int, userId: Int)
    case notifications
    case acceptGroupInvite(inviteId: Int)
    case rejectGroupInvite(inviteId: Int)
    case dismissFriendAcceptedNotification(requestId: Int)
    case mapGroups
    case groupLiveLocations(groupId: Int)
    case groupMatchedTracks(groupId: Int)
    case mapFriendsRanking
    case mapGroupRanking(groupId: Int)
    
    var url: URL? {
        var path: String
        
        switch self {
        case .register:
            path = NetworkRoutes.baseUrl + "api/register/"
        case .accessToken:
            path = NetworkRoutes.baseUrl + "api/auth/token/"
        case .fatchData:
            path = NetworkRoutes.baseUrl + "api/login_data/"
        case .searchUsers(query: let query):
            path = NetworkRoutes.baseUrl + "api/users/?q=\(query)"
        case .createFriendRequest:
            path = NetworkRoutes.baseUrl + "api/friend-requests/"
        case .incomingFriendRequest:
            path = NetworkRoutes.baseUrl + "api/friend-requests/incoming/"
        case .outgoingFriendRequest:
            path = NetworkRoutes.baseUrl + "api/friend-requests/outgoing/"
        case .acceptFriendRequest(id: let id):
            path = NetworkRoutes.baseUrl + "api/friend-requests/\(id)/accept/"
        case .rejectFriendRequest(id: let id):
            path = NetworkRoutes.baseUrl + "api/friend-requests/\(id)/reject/"
        case .friendsList:
            path = NetworkRoutes.baseUrl + "api/friends/"
        case .deleteFriend(id: let id):
            path = NetworkRoutes.baseUrl + "api/friends/\(id)/"
        case .resetPasswordRequest:
            path = NetworkRoutes.baseUrl + "api/password-reset/request/"
        case .passwordResetRequest:
            path = NetworkRoutes.baseUrl + "api/password-reset/"
        case .passwordResetVerify:
            path = NetworkRoutes.baseUrl + "api/password-reset/verify/"
        case .passwordResetConfirm:
            path = NetworkRoutes.baseUrl + "api/password-reset/confirm/"
        case .syncTodaySteps:
            path = NetworkRoutes.baseUrl + "api/steps/sync/"
        case .friendsLeaderboard:
            path = NetworkRoutes.baseUrl + "api/friends/leaderboard/"
        case .registerVerify:
            path = NetworkRoutes.baseUrl + "api/register/verify/"
        case .registerResend:
            path = NetworkRoutes.baseUrl + "api/register/resend/"
        case .setUsername:
            path = NetworkRoutes.baseUrl + "api/profile/username/"
        case .myProfile:
            path = NetworkRoutes.baseUrl + "api/profile/me/"
        case .profileAvatar:
            path = NetworkRoutes.baseUrl + "api/profile/avatar/"
        case .deleteProfileAvatar:
            path = NetworkRoutes.baseUrl + "api/profile/avatar/"
        case .updateLiveLocation:
            path = NetworkRoutes.baseUrl + "api/map/live-location/"
        case .friendsLiveLocation:
            path = NetworkRoutes.baseUrl + "api/map/friends-live/"
        case .userCard(id: let id):
            path = NetworkRoutes.baseUrl + "api/users/\(id)/card/"
        case .removeFriend(let userID):
            path = NetworkRoutes.baseUrl + "api/friends/\(userID)/"
        case .cancelFriendRequest(let userID):
            path = NetworkRoutes.baseUrl + "api/friend-requests/\(userID)/cancel/"
        case .uploadTrackPoints:
            path = NetworkRoutes.baseUrl + "api/map/track-points/"
        case .myTrack:
            path = NetworkRoutes.baseUrl + "api/map/my-track/?day=today"
        case .friendsTracks:
            path = NetworkRoutes.baseUrl + "api/map/friends-tracks/?day=today"
        case .myMatchedTrack:
            path = NetworkRoutes.baseUrl + "api/map/my-matched-track/?day=today"
        case .friendsMatchedTracks:
            path = NetworkRoutes.baseUrl + "api/map/friends-matched-tracks/?day=today"
        case .groups:
            path = NetworkRoutes.baseUrl + "api/groups/"
        case .createGroup:
            path = NetworkRoutes.baseUrl + "api/groups/"
        case .groupAddMember(let groupId):
            path = NetworkRoutes.baseUrl + "api/groups/\(groupId)/members/"
        case .groupRemoveMember(let groupId, let userId):
            path = NetworkRoutes.baseUrl + "api/groups/\(groupId)/members/\(userId)/"
        case .groupPromoteAdmin(let groupId, let userId):
            path = NetworkRoutes.baseUrl + "api/groups/\(groupId)/members/\(userId)/promote/"
        case .groupAvatar(let groupId):
            path = NetworkRoutes.baseUrl + "api/groups/\(groupId)/avatar/"
        case .groupDetail(let groupId):
            path = NetworkRoutes.baseUrl + "api/groups/\(groupId)/"
        case .groupLeaderboard(let groupId, let period):
            path = NetworkRoutes.baseUrl + "api/groups/\(groupId)/leaderboard/?period=\(period)"
        case .groupLeave(let groupId):
            path = NetworkRoutes.baseUrl + "api/groups/\(groupId)/leave/"
        case .updateGroup(let groupId):
            path = NetworkRoutes.baseUrl + "api/groups/\(groupId)/"
        case .groupDemoteAdmin(let groupId, let userId):
            path = NetworkRoutes.baseUrl + "api/groups/\(groupId)/members/\(userId)/demote/"
        case .notifications:
            path = NetworkRoutes.baseUrl + "api/notifications/"
        case .acceptGroupInvite(let inviteId):
            path = NetworkRoutes.baseUrl + "api/group-invites/\(inviteId)/accept/"
        case .rejectGroupInvite(let inviteId):
            path = NetworkRoutes.baseUrl + "api/group-invites/\(inviteId)/reject/"
        case .dismissFriendAcceptedNotification(let requestId):
            path = NetworkRoutes.baseUrl + "api/notifications/friend-request-accepted/\(requestId)/dismiss/"
        case .mapGroups:
            path = NetworkRoutes.baseUrl + "api/map/groups/"
        case .groupLiveLocations(let groupId):
            path = NetworkRoutes.baseUrl + "api/map/groups/\(groupId)/live/"
        case .groupMatchedTracks(let groupId):
            path = NetworkRoutes.baseUrl + "api/map/groups/\(groupId)/matched-tracks/"
        case .mapFriendsRanking:
            path = NetworkRoutes.baseUrl + "api/map/ranking/"
        case .mapGroupRanking(let groupId):
            path = NetworkRoutes.baseUrl + "api/map/groups/\(groupId)/ranking/"
        }

        return URL(string: path)
    }
    
    var method: HttpMethod {
        switch self {
        case .register:
            return .post
        case .accessToken:
            return .post
        case .fatchData:
            return .get
        case .searchUsers:
            return .get
        case .createFriendRequest:
            return .post
        case .incomingFriendRequest:
            return .get
        case .outgoingFriendRequest:
            return .get
        case .acceptFriendRequest:
            return .post
        case .rejectFriendRequest:
            return .post
        case .friendsList:
            return .get
        case .deleteFriend:
            return .delete
        case .resetPasswordRequest:
            return .post
        case .passwordResetRequest:
            return .post
        case .passwordResetVerify:
            return .post
        case .passwordResetConfirm:
            return .post
        case .syncTodaySteps:
            return .post
        case .friendsLeaderboard:
            return .get
        case .registerVerify:
            return .post
        case .registerResend:
            return .post
        case .setUsername:
            return .post
        case .myProfile:
            return .get
        case .profileAvatar:
            return .put
        case .deleteProfileAvatar:
            return .delete
        case .updateLiveLocation:
            return .post
        case .friendsLiveLocation:
            return .get
        case .userCard:
            return .get
        case .removeFriend:
            return .delete
        case .cancelFriendRequest:
            return .delete
        case .uploadTrackPoints:
            return .post
        case .myTrack:
            return .get
        case .friendsTracks:
            return .get
        case .myMatchedTrack:
            return .get
        case .friendsMatchedTracks:
            return .get
        case .groups:
            return .get
        case .createGroup:
            return .post
        case .groupAddMember:
            return .post
        case .groupRemoveMember:
            return .delete
        case .groupPromoteAdmin:
            return .post
        case .groupAvatar:
            return .put
        case .groupDetail:
            return .get
        case .groupLeaderboard:
            return .get
        case .groupLeave:
            return .post
        case .updateGroup:
            return .patch
        case .groupDemoteAdmin:
            return .post
        case .notifications:
            return .get
        case .acceptGroupInvite:
            return .post
        case .rejectGroupInvite:
            return .post
        case .dismissFriendAcceptedNotification:
            return .post
        case .mapGroups:
            return .get
        case .groupLiveLocations:
            return .get
        case .groupMatchedTracks:
            return .get
        case .mapFriendsRanking:
            return .get
        case .mapGroupRanking:
            return .get
        }
    }
}
