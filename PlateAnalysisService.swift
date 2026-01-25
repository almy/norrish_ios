import Foundation
import UIKit

struct PlateAnalysisService {
    
    struct APIError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    
    // TODO: Replace with your actual API endpoint URL
    static let endpoint = URL(string: "https://your.api/plate/analyze")!
    
    static func analyze(image: UIImage, authToken: String? = nil) async throws -> PlateAnalysis {
        // Prepare URLRequest
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        
        // Boundary for multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // TODO: Add authorization header if needed
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create multipart form data body
        let httpBody = try createBody(with: image, boundary: boundary)
        request.httpBody = httpBody
        
        // Configure URLSession with sensible timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        
        // Perform the request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid server response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError(message: "Server error \(httpResponse.statusCode): \(message)")
        }
        
        // Decode the response data into PlateAnalysis model
        do {
            let decoder = JSONDecoder()
            let analysis = try decoder.decode(PlateAnalysis.self, from: data)
            return analysis
        } catch {
            throw APIError(message: "Failed to decode response: \(error.localizedDescription)")
        }
    }
    
    private static func createBody(with image: UIImage, boundary: String) throws -> Data {
        var body = Data()
        
        // Convert image to JPEG data with reasonable compression
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError(message: "Unable to convert image to JPEG data")
        }
        
        let lineBreak = "\r\n"
        
        // Append image data as form field "file"
        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\(lineBreak)")
        body.append("Content-Type: image/jpeg\(lineBreak)\(lineBreak)")
        body.append(imageData)
        body.append(lineBreak)
        
        // TODO: Append additional form fields here if needed
        // Example:
        // body.append("--\(boundary)\(lineBreak)")
        // body.append("Content-Disposition: form-data; name=\"someField\"\(lineBreak)\(lineBreak)")
        // body.append("someValue\(lineBreak)")
        
        // Closing boundary
        body.append("--\(boundary)--\(lineBreak)")
        
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
