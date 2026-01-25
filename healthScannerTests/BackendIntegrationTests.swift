import XCTest
@testable import healthScanner

final class BackendIntegrationTests: XCTestCase {
    private func requiredEnv(_ name: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[name],
              !value.isEmpty else {
            throw XCTSkip("Set \(name) to run this integration test.")
        }
        return value
    }

    private func envOrDefault(_ name: String, defaultValue: String) -> String {
        let value = ProcessInfo.processInfo.environment[name]
        return value?.isEmpty == false ? value! : defaultValue
    }

    private func requireBackendConfig() throws {
        let hasEnvBaseURL = ProcessInfo.processInfo.environment["API_BASE_URL"]?.isEmpty == false
        let hasEnvApiKey = ProcessInfo.processInfo.environment["API_KEY"]?.isEmpty == false
        let hasPlistBaseURL = AppConfig.apiBaseURL?.isEmpty == false
        let hasPlistApiKey = AppConfig.apiKey?.isEmpty == false
        
        

        if (hasEnvBaseURL || hasPlistBaseURL) && (hasEnvApiKey || hasPlistApiKey) {
            return
        }

        throw XCTSkip("Set API_BASE_URL and API_KEY (env or AppConfig.plist) to run this integration test.")
    }

    private func performBackendCall<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            // Skip if blocked by Vercel security checkpoint
            if case BackendAPIError.httpError(let statusCode, let body) = error,
               statusCode == 429,
               body.contains("Vercel Security Checkpoint") {
                throw XCTSkip("Backend blocked by Vercel Security Checkpoint (429).")
            }
            // Skip on URLSession timeout
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw XCTSkip("Backend request timed out.")
            }
            // Skip on CFNetwork stream timeout (-2102 in domain 4)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain || nsError.domain == kCFErrorDomainCFNetwork as String {
                if let streamCode = nsError.userInfo["_kCFStreamErrorCodeKey"] as? Int,
                   let streamDomain = nsError.userInfo["_kCFStreamErrorDomainKey"] as? Int,
                   streamCode == -2102, streamDomain == 4 {
                    throw XCTSkip("Network stream timeout (-2102).")
                }
            }
            throw error
        }
    }

    func testBarcodeScanFromBackendCatalog() async throws {
        try requireBackendConfig()
        let ean = envOrDefault("TEST_EAN_EXISTING", defaultValue: "00000073107552")

        let response: BackendBarcodeResponse = try await performBackendCall {
            try await BackendAPIClient.shared.post(
                endpoint: BackendAPIClient.shared.endpoints.scanBarcode,
                body: BackendBarcodeRequest(barcode: ean, locale: "en")
            )
        }

        XCTAssertFalse(response.scanId.isEmpty)
        XCTAssertFalse(response.status.isEmpty)
        XCTAssertEqual(response.product.barcode, ean)
        XCTAssertFalse(response.product.name.isEmpty)
        XCTAssertFalse(response.product.brand.isEmpty)
    }

    func testBarcodeScanFallsBackToOpenData() async throws {
        try requireBackendConfig()
        let ean = envOrDefault("TEST_EAN_OPENDATA", defaultValue: "3017620425035")

        let response: BackendBarcodeResponse = try await performBackendCall {
            try await BackendAPIClient.shared.post(
                endpoint: BackendAPIClient.shared.endpoints.scanBarcode,
                body: BackendBarcodeRequest(barcode: ean, locale: "en")
            )
        }

        XCTAssertFalse(response.scanId.isEmpty)
        XCTAssertFalse(response.status.isEmpty)
        XCTAssertEqual(response.product.barcode, ean)
        XCTAssertFalse(response.product.name.isEmpty)

        if let expectedBrand = ProcessInfo.processInfo.environment["TEST_OPENDATA_EXPECTED_BRAND"],
           !expectedBrand.isEmpty {
            XCTAssertEqual(response.product.brand, expectedBrand)
        }
    }

    func testPlateScanReturnsAnalysis() async throws {
        try requireBackendConfig()
        let imagePath = ProcessInfo.processInfo.environment["TEST_PLATE_IMAGE_PATH"]
        let imageData: Data
        if let imagePath, !imagePath.isEmpty {
            imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        } else {
            let bundle = Bundle(for: BackendIntegrationTests.self)
            let imageURL = try XCTUnwrap(bundle.url(forResource: "plate", withExtension: "jpg"))
            imageData = try Data(contentsOf: imageURL)
        }
        let contextPayload: [String: String] = [
            "device": "integration-test",
            "method": "upload"
        ]
        let contextData = try JSONSerialization.data(withJSONObject: contextPayload, options: [])
        let contextJSON = String(data: contextData, encoding: .utf8)

        func attempt() async throws -> BackendPlateScanResponse {
            try await performBackendCall {
                try await BackendAPIClient.shared.postMultipart(
                    endpoint: BackendAPIClient.shared.endpoints.scanPlateAI,
                    imageData: imageData,
                    contextJSON: contextJSON
                )
            }
        }

        let response: BackendPlateScanResponse
        do {
            response = try await attempt()
        } catch {
            // Retry once on transient timeouts
            if let urlError = error as? URLError, urlError.code == .timedOut {
                response = try await attempt()
            } else {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain || nsError.domain == kCFErrorDomainCFNetwork as String,
                   let streamCode = nsError.userInfo["_kCFStreamErrorCodeKey"] as? Int,
                   let streamDomain = nsError.userInfo["_kCFStreamErrorDomainKey"] as? Int,
                   streamCode == -2102, streamDomain == 4 {
                    response = try await attempt()
                } else {
                    throw error
                }
            }
        }

        XCTAssertFalse(response.scanId.isEmpty)
        XCTAssertFalse(response.status.isEmpty)
        XCTAssertFalse(response.analysis.description.isEmpty)
        XCTAssertFalse(response.analysis.ingredients.isEmpty)
        XCTAssertGreaterThan(response.analysis.macronutrients.calories, 0)
    }

    // Intentionally no helper for bundled resource lookup beyond the test itself.
}
