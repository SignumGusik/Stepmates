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
    case patch = "PATCH"
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
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            print("HTTP ERROR:", statusCode)
            print("URL:", urlRequest.url?.absoluteString ?? "nil")
            print("BODY:", body)
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
    func uploadAvatar<ResponseType: Decodable>(
        _ url: URL,
        imageData: Data,
        fileName: String = "avatar.jpg",
        mimeType: String = "image/jpeg",
        responseType: ResponseType.Type,
        accessToken: String
    ) async throws -> ResponseType {

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = HttpMethod.put.rawValue
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        // multipart body
        var body = Data()

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"avatar\"; filename=\"\(fileName)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noResponse
        }
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.failedStatusCodeResponseData(httpResponse.statusCode, data)
        }

        return try JSONDecoder().decode(responseType, from: data)
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

