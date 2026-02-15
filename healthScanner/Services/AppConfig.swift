import Foundation

enum AppConfig {
    private enum Keys {
        static let baseURL = "API_BASE_URL"
        static let apiKey = "API_KEY"
        static let jwtToken = "JWT_TOKEN"
        static let timeoutSeconds = "API_TIMEOUT_SECONDS"
    }

    static var apiBaseURL: String? {
        stringValue(forKey: Keys.baseURL)
    }

    static var apiKey: String? {
        stringValue(forKey: Keys.apiKey)
    }

    static var jwtToken: String? {
        stringValue(forKey: Keys.jwtToken)
    }

    static var requestTimeout: TimeInterval {
        if let value = numberValue(forKey: Keys.timeoutSeconds) {
            return value.doubleValue
        }
        return 30
    }

    static func startupValidationError() -> String? {
        var issues: [String] = []

        if let baseURL = apiBaseURL, !baseURL.isEmpty {
            if URL(string: baseURL) == nil {
                issues.append("API_BASE_URL is not a valid URL.")
            }
        } else {
            issues.append("API_BASE_URL is missing.")
        }

        if apiKey?.isEmpty != false {
            issues.append("API_KEY is missing.")
        }

        guard !issues.isEmpty else { return nil }
        return issues.joined(separator: "\n")
    }

    private static func stringValue(forKey key: String) -> String? {
        if let envValue = environmentString(forKey: key) {
            return envValue
        }
        if let value = configDictionary()[key] as? String, !value.isEmpty {
            return value
        }
        if let infoValue = Bundle.main.object(forInfoDictionaryKey: key) as? String, !infoValue.isEmpty {
            return infoValue
        }
        return nil
    }

    private static func numberValue(forKey key: String) -> NSNumber? {
        if let envValue = environmentNumber(forKey: key) {
            return envValue
        }
        if let value = configDictionary()[key] as? NSNumber {
            return value
        }
        if let infoValue = Bundle.main.object(forInfoDictionaryKey: key) as? NSNumber {
            return infoValue
        }
        return nil
    }

    private static func environmentString(forKey key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]
        return value?.isEmpty == false ? value : nil
    }

    private static func environmentNumber(forKey key: String) -> NSNumber? {
        guard let value = environmentString(forKey: key),
              let number = Double(value) else {
            return nil
        }
        return NSNumber(value: number)
    }

    private static func configDictionary() -> [String: Any] {
        cachedConfig
    }

    private static let cachedConfig: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "AppConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any]
        else { return [:] }

        return dict
    }()
}
