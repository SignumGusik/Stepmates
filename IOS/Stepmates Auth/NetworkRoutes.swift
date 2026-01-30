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
    
    var url: URL? {
        var path: String
        switch self {
        case .register:
            path = NetworkRoutes.baseUrl + "api/register/"
        
        case .accessToken:
            path = NetworkRoutes.baseUrl + "api/auth/token/"
        case .fatchData:
            path = NetworkRoutes.baseUrl + "api/login_data/"
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
        }
        
    }
}

