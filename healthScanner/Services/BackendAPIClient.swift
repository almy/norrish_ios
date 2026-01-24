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
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }
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
}
