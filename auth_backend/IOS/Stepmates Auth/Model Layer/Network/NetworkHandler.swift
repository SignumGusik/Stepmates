//
//  NetworkHandler.swift
//  Stepmates Auth
//
//  Created by Диана on 27/01/2026.
//

import Foundation

enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum ContentType: String {
    case json = "application/json; charset=utf-8"
}

class NetworkHandler {
    func request(
        _ url: URL,
        jsonDictionary: Any? = nil,
        httpMethod: String = HttpMethod.get.rawValue,
        contentType: String = ContentType.json.rawValue,
        accessToken: String? = nil
    ) async throws -> Data {
        var urlRequest = makeUrlRequest(url, httpMethod: httpMethod, contentType: contentType, accessToken: accessToken)
        if let jsonDictionary, let httpBody = try? JSONSerialization.data(withJSONObject: jsonDictionary) {
            urlRequest.httpBody = httpBody
        } else if jsonDictionary != nil {
            print("Could not aerialize object into JSON data")
            throw ConfigurationError.nilObject
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Could not create HTTPURLResponse for: \(urlRequest.url?.absoluteString ?? "")")
            throw NetworkError.noResponse
        }
        let statusCode = httpResponse.statusCode
        guard 200...299 ~= statusCode else {
            throw NetworkError.failedStatusCodeResponseData(statusCode, data)
        }
        return data
    }
    
    func request<ResponseType: Decodable>(
        _ url: URL,
        jsonDictionary: Any? = nil,
        responseType: ResponseType.Type,
        httpMethod: String = HttpMethod.get.rawValue,
        contentType: String = ContentType.json.rawValue,
        accessToken: String? = nil
    ) async throws -> ResponseType {
        let data = try await request(
            url,
            jsonDictionary: jsonDictionary,
            httpMethod: httpMethod,
            contentType: contentType,
            accessToken: accessToken
        )
        return try JSONDecoder().decode(responseType, from: data)
    }
}

// MARK: -Making REguests

extension NetworkHandler {
    func makeUrlRequest(
        _ url: URL,
        httpMethod: String = HttpMethod.get.rawValue,
        contentType: String? = ContentType.json.rawValue,
        accessToken: String? = nil
    ) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = httpMethod
        
        if let contentType {
            urlRequest.addValue(contentType, forHTTPHeaderField: "Content-Type")
            
            if contentType.range(of: "json") != nil {
                urlRequest.addValue(contentType, forHTTPHeaderField: "Accept")
            }
        }
        
        if let accessToken {
            let authorizationKey = "Bearer ".appending(accessToken)
            urlRequest.addValue(authorizationKey, forHTTPHeaderField: "Authorization")
            
        }
        return urlRequest
    }
}
