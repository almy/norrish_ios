import Foundation

enum BackendAPIError: LocalizedError {
    case missingConfig(String)
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case encodingFailed
    case decodingFailed

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
        case .decodingFailed:
            return "Failed to decode backend response."
        }
    }
}

struct BackendAPIEndpoints {
    let health = "/v1/health"
    let scanPlate = "/v1/scans/plate"
    let scanPlateAI = "/v1/scans/plate/ai"
    let scanBarcode = "/v1/scans/barcode"
    let nutriscore = "/v1/nutriscore"
    let recommendations = "/v1/recommendations"
    let visionAnalyze = "/v1/vision/analyze"
    let register = "/v1/auth/register"
    let login = "/v1/auth/login"
    let profile = "/v1/profile"
}

final class BackendAPIClient {
    static let shared = BackendAPIClient()
    let endpoints = BackendAPIEndpoints()

    private init() {}

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
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        func appendFileField(name: String, filename: String, mimeType: String, fileData: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }

        if let contextJSON {
            appendFormField(name: "context", value: contextJSON)
        }
        appendFileField(name: "image", filename: imageFilename, mimeType: mimeType, fileData: imageData)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // DEBUG: Log multipart payload in a readable form
        #if DEBUG
        do {
            let urlString = request.url?.absoluteString ?? "<no url>"
            let apiKeyHeader = request.value(forHTTPHeaderField: "X-API-Key") ?? ""
            let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? "multipart/form-data"
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            print("[BackendAPI] Multipart payload:")
            if let contextJSON {
                print("[BackendAPI] context JSON: \(truncate(contextJSON))")
            } else {
                print("[BackendAPI] context JSON: <none>")
            }
            print("[BackendAPI] image bytes: \(imageData.count)")

            // Pseudo curl for multipart (-F fields); file is in-memory, so we show a placeholder
            print("[BackendAPI] POST multipart curl (pseudo):")
            var curl = "curl -X POST '\(urlString)' \\\n  -H 'Content-Type: \(contentType)' \\\n  -H 'X-API-Key: \(apiKeyHeader)' \\"
            if let authHeader { curl += "\n  -H 'Authorization: \(authHeader)' \\\n" }
            if let contextJSON {
                let shortCtx = truncate(contextJSON)
                curl += "  -F 'context=\(shortCtx.replacingOccurrences(of: "'", with: "'\"'\"'"))' \\\n"
            }
            curl += "  -F 'image=@\(imageFilename);type=\(mimeType)'"
            print(curl)
        }
        #endif

        return try await send(request)
    }

    private func makeRequest(endpoint: String, method: String, token: String?) throws -> URLRequest {
        guard let baseURL = AppConfig.apiBaseURL, !baseURL.isEmpty else {
            throw BackendAPIError.missingConfig("API_BASE_URL")
        }
        guard let apiKey = AppConfig.apiKey, !apiKey.isEmpty else {
            throw BackendAPIError.missingConfig("API_KEY")
        }
        let urlString = baseURL + endpoint
        guard let url = URL(string: urlString) else {
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
        logRequest(request, apiKey: apiKey)
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
        guard let decoded = try? decoder.decode(Response.self, from: data) else {
            throw BackendAPIError.decodingFailed
        }
        return decoded
    }

    private func truncate(_ body: String, limit: Int = 800) -> String {
        guard body.count > limit else { return body }
        return String(body.prefix(limit)) + "…"
    }

    private func logRequest(_ request: URLRequest, apiKey: String) {
        #if DEBUG
        let shouldLog = true
        #else
        let shouldLog = ProcessInfo.processInfo.environment["BACKEND_DEBUG"] == "1"
        #endif
        guard shouldLog else { return }

        let urlString = request.url?.absoluteString ?? "<no url>"
        let method = request.httpMethod ?? "<no method>"
        let authHeader = request.value(forHTTPHeaderField: "Authorization")
        print("[BackendAPI] \(method) \(urlString)")
        print("[BackendAPI] X-API-Key: \(apiKey)")
        print("[BackendAPI] Authorization: \(authHeader ?? "<none>")")
        if method.uppercased() == "POST" {
            let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? "application/json"
            let bodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let escapedBody = bodyString.replacingOccurrences(of: "'", with: "'\"'\"'")
            let authLine = authHeader.map { "  -H 'Authorization: \($0)' \\\n" } ?? ""
            let curl = """
            curl -X POST '\(urlString)' \\
              -H 'Content-Type: \(contentType)' \\
              -H 'X-API-Key: \(apiKey)' \\
            \(authLine)  -d '\(escapedBody)'
            """
            print("[BackendAPI] POST curl:\n\(curl)")
        }
    }

    private func maskSecret(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "****" }
        let suffix = trimmed.suffix(4)
        return "****\(suffix)"
    }

    private func logResponse(httpResponse: HTTPURLResponse, data: Data) {
        #if DEBUG
        let shouldLog = true
        #else
        let shouldLog = ProcessInfo.processInfo.environment["BACKEND_DEBUG"] == "1"
        #endif
        guard shouldLog else { return }

        let urlString = httpResponse.url?.absoluteString ?? "<no url>"
        let status = httpResponse.statusCode
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        print("[BackendAPI] Response \(status) \(urlString)")
        print("[BackendAPI] Response body: \(body)")
    }
}
