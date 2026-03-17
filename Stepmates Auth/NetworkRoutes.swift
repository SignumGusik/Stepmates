//
//  NetworkRoutes.swift
//  Stepmates Auth
//
//  Created by Диана on 27/01/2026.
//

import Foundation


enum NetworkRoutes {
    private static let baseUrl = "http://127.0.0.1:8000/"
    
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
        case .passwordResetConfirm:
            return .post
        case .passwordResetVerify:
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
        }
        
    }
}

