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
    private let tokenStorage: AccessTokenStorage?

    init(tokenStorage: AccessTokenStorage? = nil) {
        self.tokenStorage = tokenStorage
    }

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
            print("Could not serialize object into JSON data")
            throw ConfigurationError.nilObject
        }

        do {
            return try await perform(urlRequest)
        } catch NetworkError.failedStatusCodeResponseData(let statusCode, let responseData) where statusCode == 401 {
            guard accessToken != nil else {
                throw NetworkError.failedStatusCodeResponseData(statusCode, responseData)
            }

            guard let refreshedToken = try await refreshAccessToken() else {
                throw NetworkError.failedStatusCodeResponseData(statusCode, responseData)
            }

            var retryRequest = makeUrlRequest(
                url,
                httpMethod: httpMethod,
                contentType: contentType,
                accessToken: refreshedToken.accessToken
            )
            retryRequest.httpBody = urlRequest.httpBody
            return try await perform(retryRequest)
        }
    }

    private func perform(_ urlRequest: URLRequest) async throws -> Data {
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

    func refreshAccessToken() async throws -> AccessToken? {
        guard let tokenStorage,
              let currentToken = tokenStorage.get() else {
            return nil
        }

        guard let url = NetworkRoutes.refreshToken.url else {
            throw ConfigurationError.nilObject
        }

        var request = makeUrlRequest(
            url,
            httpMethod: NetworkRoutes.refreshToken.method.rawValue,
            contentType: ContentType.json.rawValue,
            accessToken: nil
        )
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["refresh": currentToken.refreshToken]
        )

        do {
            let data = try await perform(request)
            let response = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
            let updatedToken = AccessToken(
                accessToken: response.access,
                refreshToken: response.refresh ?? currentToken.refreshToken
            )

            tokenStorage.save(updatedToken)
            return updatedToken
        } catch NetworkError.failedStatusCodeResponseData(let statusCode, let responseData) where statusCode == 400 || statusCode == 401 {
            tokenStorage.delete()
            throw NetworkError.failedStatusCodeResponseData(statusCode, responseData)
        } catch {
            throw error
        }
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

        func performUpload(accessToken: String, canRefreshToken: Bool) async throws -> ResponseType {
            let boundary = "Boundary-\(UUID().uuidString)"

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.put.rawValue
            request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

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

            if 200...299 ~= httpResponse.statusCode {
                return try JSONDecoder().decode(responseType, from: data)
            }

            if httpResponse.statusCode == 401,
               canRefreshToken,
               let refreshedToken = try await refreshAccessToken() {
                return try await performUpload(
                    accessToken: refreshedToken.accessToken,
                    canRefreshToken: false
                )
            }

            throw NetworkError.failedStatusCodeResponseData(httpResponse.statusCode, data)
        }

        return try await performUpload(accessToken: accessToken, canRefreshToken: true)
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
