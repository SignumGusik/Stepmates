//
//  NetworkError.swift
//  Stepmates Auth
//
//  Created by Диана on 27/01/2026.
//

import Foundation

enum NetworkError: Error {
    case UserError(String)
    case dateError(String)
    case encodingError
    case decodingError
    case failedStatusCode(String)
    case failedStatusCodeResponseData(Int, Data)
    case noResponse
    
    var statusCodeResponseData: (Int, Data)? {
        if case let .failedStatusCodeResponseData(statusCode, responseData) = self {
            return (statusCode, responseData)
        }
        return nil
    }
}
