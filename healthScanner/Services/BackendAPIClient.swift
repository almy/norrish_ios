import Foundation

protocol PlateScanAPIClient {
    func postPlateScanAI(imageData: Data, contextJSON: String?) async throws -> BackendPlateScanResponse
}

enum BackendAPIError: LocalizedError {
    case missingConfig(String)
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case encodingFailed
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfig(let key):
            return "Missing configuration for \(key)."
        case .invalidURL(let url):
            return "Invalid API URL: \(url)"
        case .invalidResponse:
            return "Invalid response from backend."
        case .httpError(let statusCode, let body):
            return "Backend error \(statusCode): \(body)"
        case .encodingFailed:
            return "Failed to encode request body."
        case .decodingFailed(let details):
            return "Failed to decode backend response: \(details)"
        }
    }
}

struct BackendAPIEndpoints {
    let health = "/v1/health"
    let scanPlate = "/v1/scans/plate"
    let scanPlateAI = "/v1/scans/plate/ai"
    let scanBarcode = "/v2/scans/barcode"
    let nutriscore = "/v1/nutriscore"
    let recommendations = "/v1/recommendations"
    let similarProducts = "/v2/products/similar"
    let visionAnalyze = "/v1/vision/analyze"
    let register = "/v1/auth/register"
    let login = "/v1/auth/login"
    let profile = "/v1/profile"
}

final class BackendAPIClient {
    static let shared = BackendAPIClient()
    let endpoints = BackendAPIEndpoints()

    private init() {}

    private var shouldLogNetwork: Bool {
        ProcessInfo.processInfo.environment["BACKEND_DEBUG"] == "1"
    }

    func post<Body: Encodable, Response: Decodable>(
        endpoint: String,
        body: Body,
        token: String? = nil
    ) async throws -> Response {
        var request = try makeRequest(endpoint: endpoint, method: "POST", token: token)
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(body) else {
            throw BackendAPIError.encodingFailed
        }
        request.httpBody = data

        return try await send(request)
    }

    func get<Response: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        token: String? = nil
    ) async throws -> Response {
        let request = try makeRequest(
            endpoint: endpoint,
            method: "GET",
            token: token,
            queryItems: queryItems
        )
        return try await send(request)
    }

    func postMultipart<Response: Decodable>(
        endpoint: String,
        imageData: Data,
        imageFilename: String = "photo.jpg",
        mimeType: String = "image/jpeg",
        contextJSON: String? = nil,
        token: String? = nil
    ) async throws -> Response {
        var request = try makeRequest(endpoint: endpoint, method: "POST", token: token)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        func appendFormField(name: String, value: String) {
            let safeName = sanitizeMultipartFieldName(name)
            let safeValue = sanitizeMultipartFieldValue(value, boundary: boundary)
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(safeName)\"\r\n\r\n".utf8))
            body.append(Data("\(safeValue)\r\n".utf8))
        }

        func appendFileField(name: String, filename: String, mimeType: String, fileData: Data) {
            let safeName = sanitizeMultipartFieldName(name)
            let safeFilename = sanitizeMultipartFilename(filename)
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(safeName)\"; filename=\"\(safeFilename)\"\r\n".utf8))
            body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
            body.append(fileData)
            body.append(Data("\r\n".utf8))
        }

        if let contextJSON {
            appendFormField(name: "context", value: contextJSON)
        }
        appendFileField(name: "image", filename: imageFilename, mimeType: mimeType, fileData: imageData)
        body.append(Data("--\(boundary)--\r\n".utf8))

        request.httpBody = body

        if shouldLogNetwork {
            let urlString = request.url?.absoluteString ?? "<no url>"
            let apiKeyHeader = request.value(forHTTPHeaderField: "X-API-Key") ?? ""
            let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? "multipart/form-data"
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            let maskedApiKeyHeader = maskSecret(apiKeyHeader)
            let maskedAuthHeader = maskAuthorizationHeader(authHeader)
            AppLog.debug(AppLog.network, "[BackendAPI] Multipart payload:")
            if let contextJSON {
                AppLog.debug(AppLog.network, "[BackendAPI] context JSON: \(truncate(contextJSON))")
            } else {
                AppLog.debug(AppLog.network, "[BackendAPI] context JSON: <none>")
            }
            AppLog.debug(AppLog.network, "[BackendAPI] image bytes: \(imageData.count)")

            // Pseudo curl for multipart (-F fields); file is in-memory, so we show a placeholder
            AppLog.debug(AppLog.network, "[BackendAPI] POST multipart curl (pseudo):")
            var curl = "curl -X POST '\(urlString)' \\\n  -H 'Content-Type: \(contentType)' \\\n  -H 'X-API-Key: \(maskedApiKeyHeader)' \\"
            if authHeader != nil { curl += "\n  -H 'Authorization: \(maskedAuthHeader)' \\\n" }
            if let contextJSON {
                let shortCtx = truncate(contextJSON)
                curl += "  -F 'context=\(shortCtx.replacingOccurrences(of: "'", with: "'\"'\"'"))' \\\n"
            }
            curl += "  -F 'image=@\(imageFilename);type=\(mimeType)'"
            AppLog.debug(AppLog.network, curl)
        }

        return try await send(request)
    }

    private func makeRequest(
        endpoint: String,
        method: String,
        token: String?,
        queryItems: [URLQueryItem] = []
    ) throws -> URLRequest {
        guard let baseURL = AppConfig.apiBaseURL, !baseURL.isEmpty else {
            throw BackendAPIError.missingConfig("API_BASE_URL")
        }
        guard let apiKey = AppConfig.apiKey, !apiKey.isEmpty else {
            throw BackendAPIError.missingConfig("API_KEY")
        }
        let urlString = baseURL + endpoint
        guard var components = URLComponents(string: urlString) else {
            throw BackendAPIError.invalidURL(urlString)
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw BackendAPIError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = AppConfig.requestTimeout
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        logRequest(request)
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }
        logResponse(httpResponse: httpResponse, data: data)
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw BackendAPIError.httpError(statusCode: httpResponse.statusCode, body: truncate(body))
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            let details = "\(String(describing: Response.self)): \(error.localizedDescription). body=\(truncate(body))"
            throw BackendAPIError.decodingFailed(details)
        }
    }

    private func truncate(_ body: String, limit: Int = 800) -> String {
        guard body.count > limit else { return body }
        return String(body.prefix(limit)) + "…"
    }

    private func sanitizeMultipartFieldName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-."))
        let sanitizedScalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(sanitizedScalars)
    }

    private func sanitizeMultipartFieldValue(_ value: String, boundary: String) -> String {
        var sanitized = value.replacingOccurrences(of: "\r\n", with: "\n")
        sanitized = sanitized.replacingOccurrences(of: "\r", with: "\n")
        sanitized = sanitized.replacingOccurrences(of: "--\(boundary)", with: "-- \(boundary)")
        return sanitized
    }

    private func sanitizeMultipartFilename(_ value: String) -> String {
        var sanitized = value.replacingOccurrences(of: "\"", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "\r", with: "")
        sanitized = sanitized.replacingOccurrences(of: "\n", with: "")
        return sanitized
    }

    private func logRequest(_ request: URLRequest) {
        guard shouldLogNetwork else { return }

        let urlString = request.url?.absoluteString ?? "<no url>"
        let method = request.httpMethod ?? "<no method>"
        let apiKey = request.value(forHTTPHeaderField: "X-API-Key") ?? ""
        let authHeader = request.value(forHTTPHeaderField: "Authorization")
        AppLog.debug(AppLog.network, "[BackendAPI] \(method) \(urlString)")
        AppLog.debug(AppLog.network, "[BackendAPI] X-API-Key: \(maskSecret(apiKey))")
        AppLog.debug(AppLog.network, "[BackendAPI] Authorization: \(maskAuthorizationHeader(authHeader))")
        if method.uppercased() == "POST" {
            let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? "application/json"
            let bodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let escapedBody = bodyString.replacingOccurrences(of: "'", with: "'\"'\"'")
            let authLine = authHeader.map { _ in "  -H 'Authorization: \(maskAuthorizationHeader(authHeader))' \\\n" } ?? ""
            let curl = """
            curl -X POST '\(urlString)' \\
              -H 'Content-Type: \(contentType)' \\
              -H 'X-API-Key: \(maskSecret(apiKey))' \\
            \(authLine)  -d '\(escapedBody)'
            """
            AppLog.debug(AppLog.network, "[BackendAPI] POST curl:\n\(curl)")
        }
    }

    private func maskSecret(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "****" }
        let suffix = trimmed.suffix(4)
        return "****\(suffix)"
    }

    private func maskAuthorizationHeader(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "<none>" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") {
            let token = String(trimmed.dropFirst("Bearer ".count))
            return "Bearer \(maskSecret(token))"
        }
        return maskSecret(trimmed)
    }

    private func logResponse(httpResponse: HTTPURLResponse, data: Data) {
        guard shouldLogNetwork else { return }

        let urlString = httpResponse.url?.absoluteString ?? "<no url>"
        let status = httpResponse.statusCode
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        AppLog.debug(AppLog.network, "[BackendAPI] Response \(status) \(urlString)")
        AppLog.debug(AppLog.network, "[BackendAPI] Response body: \(body)")
    }
}

extension BackendAPIClient: PlateScanAPIClient {
    func postPlateScanAI(imageData: Data, contextJSON: String?) async throws -> BackendPlateScanResponse {
        try await postMultipart(
            endpoint: endpoints.scanPlateAI,
            imageData: imageData,
            contextJSON: contextJSON
        )
    }
}
