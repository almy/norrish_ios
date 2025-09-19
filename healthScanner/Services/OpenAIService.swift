// OpenAIService.swift
// Sends plate photo + metadata to OpenAI (Vision) and returns a text or JSON response.

import Foundation
import UIKit

// MARK: - Models

enum OpenAIModel: String {
    // Vision-capable chat/completions models
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    // 2025 placeholders (keep if you later switch to Responses API)
    case o4 = "o4"
    case o4Mini = "o4-mini"
    // Legacy / convenience
    case gpt4Turbo = "gpt-4-turbo"
    case gpt4o20241120 = "gpt-4o-2024-11-20"
    case gpt5 = "gpt-5"
}

/// Chat Completions response supporting either string content or array content
struct OpenAITextResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            struct ContentItem: Decodable {
                struct TextObj: Decodable { let value: String? } // when API nests text objects
                let type: String?
                let text: TextObj?
                let image_url: [String:String]?
            }
            let role: String?
            // content can be a String OR an array of ContentItem
            let content: Content
            enum Content: Decodable {
                case string(String)
                case items([ContentItem])
                init(from decoder: Decoder) throws {
                    let c = try decoder.singleValueContainer()
                    if let s = try? c.decode(String.self) {
                        self = .string(s)
                        return
                    }
                    if let arr = try? c.decode([ContentItem].self) {
                        self = .items(arr)
                        return
                    }
                    self = .string("")
                }
            }
        }
        let index: Int?
        let message: Message?
        let finish_reason: String?
    }
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]?

    var text: String {
        guard let msg = choices?.first?.message else { return "" }
        switch msg.content {
        case .string(let s): return s
        case .items(let items):
            // Concatenate any text parts present
            return items.compactMap { $0.text?.value }.joined()
        }
    }
}

/// Responses API lightweight decoder (kept for completeness; not used below)
struct OpenAIResponsesTextResponse: Decodable {
    struct OutputItem: Decodable {
        struct ContentItem: Decodable { let type: String?; let text: String? }
        let type: String?
        let role: String?
        let content: [ContentItem]?
    }
    let id: String?
    let model: String?
    let output: [OutputItem]?
    var text: String { (output ?? []).flatMap { $0.content ?? [] }.compactMap { $0.text }.joined() }
}

// MARK: - Service

final class OpenAIService {
    private let apiKey: String
    private let baseURL: URL
    private let modelName: String   // overridable via OPENAI_MODEL

    init(
        apiKey: String = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""),
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        defaultModel: OpenAIModel = .gpt4oMini
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        if let override = ProcessInfo.processInfo.environment["OPENAI_MODEL"], !override.isEmpty {
            self.modelName = override
        } else if let override = Bundle.main.object(forInfoDictionaryKey: "OPENAI_MODEL") as? String, !override.isEmpty {
            self.modelName = override
        } else {
            self.modelName = defaultModel.rawValue // vision-capable default
        }
    }

    // Context you send from your scan
    struct PlateContext: Encodable {
        let label: String
        let confidence: Float
        let volumeML: Float
        let massG: Float
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let planeStableScore: Float?
        let device: String?
        let method: String? // Analysis method
        let detectedItems: [DetectedItem]? // Detected food items
    }

    struct DetectedItem: Encodable {
        let name: String
        let confidence: Float
        let boundingBox: BoundingBox
        let pixelCount: Int?

        struct BoundingBox: Encodable {
            let x: Float
            let y: Float
            let width: Float
            let height: Float
        }
    }

    // Structured JSON you want back (screen-friendly)
    struct OpenAINutritionResponse: Decodable {
        struct Macros: Decodable { let protein_g: Double; let carbs_g: Double; let fat_g: Double; let calories_kcal: Double }
        struct Micros: Decodable { let fiber_g: Double?; let vitamin_c_mg: Double?; let iron_mg: Double?; let other: String? }
        struct Ingredient: Decodable { let name: String; let amount: String }
        struct Insight: Decodable { let type: String; let title: String; let description: String }
        struct FoodItem: Decodable {
            let name: String
            let confidence: Double
            let macros: Macros
            let amount: String
            let description: String?
        }

        let title: String
        let score: Double
        let macros: Macros
        let micros: Micros?
        let ingredients: [Ingredient]
        let foodItems: [FoodItem]? // Individual detected food items
        let insights: [Insight]
        let connections: [String]?
    }

    // MARK: Public APIs

    /// High-structure: ask model to return JSON for direct decoding into UI
    func sendPlateForNutrition(image: UIImage, context: PlateContext) async throws -> OpenAINutritionResponse {
        let optimized = optimizeImageForAPI(image)
        guard let jpeg = optimized.jpegData(compressionQuality: 0.6) else {
            throw NSError(domain: "OpenAIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }
        let b64 = jpeg.base64EncodedString()

        let prompt = buildNutritionJSONPrompt()
        let metadata = renderMetadata(context)
        let fullPrompt = prompt + "\n\n" + metadata

        print("📤 SENDING TO OPENAI - NUTRITION REQUEST:")
        print("Model: \(modelName)")
        print("Prompt: \(prompt)")
        print("Metadata: \(metadata)")
        print("Image size: \(image.size)")
        print("---")

        // Build a single user message that contains both TEXT and IMAGE
        let userMessage: [String: Any] = [
            "role": "user",
            "content": [
                ["type": "text", "text": fullPrompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
            ]
        ]

        let body: [String: Any] = [
            "model": modelName,
            "messages": [userMessage],
            "max_tokens": 900
            // NO temperature -> avoids "unsupported value" errors on some models
        ]

        let data = try await postJSON(path: "chat/completions", body: body)
        let decoded = try JSONDecoder().decode(OpenAITextResponse.self, from: data)
        let raw = decoded.text
        let json = sanitizeJSONText(raw)
        guard let jsonData = json.data(using: .utf8) else {
            throw NSError(domain: "OpenAIService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string in response"])
        }
        return try JSONDecoder().decode(OpenAINutritionResponse.self, from: jsonData)
    }

    /// Free-form: get assistant text back (you can parse/attach to insights)
    func sendPlate(image: UIImage, context: PlateContext, instruction: String? = nil) async throws -> String {
        let optimized = optimizeImageForAPI(image)
        guard let jpeg = optimized.jpegData(compressionQuality: 0.6) else {
            throw NSError(domain: "OpenAIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }
        let b64 = jpeg.base64EncodedString()

        let prompt = instruction ?? defaultTextPrompt(context: context)
        let metadata = renderMetadata(context)
        let fullPrompt = prompt + "\n\n" + metadata

        print("📤 SENDING TO OPENAI - TEXT REQUEST:")
        print("Model: \(modelName)")
        print("Prompt: \(prompt)")
        print("Metadata: \(metadata)")
        print("Image size: \(image.size)")
        print("---")

        let userMessage: [String: Any] = [
            "role": "user",
            "content": [
                ["type": "text", "text": fullPrompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
            ]
        ]

        let body: [String: Any] = [
            "model": modelName,
            "messages": [userMessage],
            "max_tokens": 600
        ]

        let data = try await postJSON(path: "chat/completions", body: body)
        let decoded = try JSONDecoder().decode(OpenAITextResponse.self, from: data)
        return decoded.text
    }

    // MARK: - Request helpers

    private func postJSON(path: String, body: [String: Any]) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "OpenAIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing OPENAI_API_KEY"])
        }
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        // (Optional) log without base64
        if let pretty = try? JSONSerialization.data(withJSONObject: redactBody(body), options: [.prettyPrinted]),
           let s = String(data: pretty, encoding: .utf8) {
            print("🔵 OpenAI Request (\(path)):\n\(s)")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let txt = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw NSError(domain: "OpenAIService", code: status, userInfo: [NSLocalizedDescriptionKey: "OpenAI error \(status): \(txt)"])
        }
        return data
    }

    // MARK: - Prompts

    private func buildNutritionJSONPrompt() -> String {
        """
        You are a nutrition and food composition expert. You will receive a meal photo, volume metadata, and detected food items.
        Produce a compact JSON object ONLY (no prose), with this schema:

        {
          "title": "Dish name",
          "score": float 0-10,
          "macros": { "protein_g": number, "carbs_g": number, "fat_g": number, "calories_kcal": number },
          "micros": { "fiber_g": number?, "vitamin_c_mg": number?, "iron_mg": number?, "other": string? },
          "ingredients": [ { "name": "string", "amount": "g or ml" } ],
          "foodItems": [
            {
              "name": "string",
              "confidence": float 0-1,
              "macros": { "protein_g": number, "carbs_g": number, "fat_g": number, "calories_kcal": number },
              "amount": "estimated portion size",
              "description": "brief nutrition note"
            }
          ],
          "insights": [
            { "type": "positive", "title": "string", "description": "string" },
            { "type": "suggestion", "title": "string", "description": "string" },
            { "type": "warning", "title": "string", "description": "string" }
          ],
          "connections": [ "hidden but relevant nutrition connections specific to this plate" ]
        }

        Rules:
        - Use the detected food items list to analyze each item individually
        - Ground portion sizes using both the overall volume metadata and individual item bounding boxes
        - For each detected food item, provide specific nutritional analysis
        - Overall macros should be the sum of individual food items
        - Be concise, supportive, and avoid medical advice
        - Output valid JSON ONLY that matches the schema above
        """
    }

    private func defaultTextPrompt(context: PlateContext) -> String {
        """
        You are a nutrition assistant.
        Analyze the meal photo and the estimated portion volume. Provide:
        • A 2–3 sentence summary describing the dish and portion size.
        • Approximate macronutrients and key micronutrients.
        • 2–3 consumer tips: at least one positive and one improvement.
        • Note uncertainty if identification or portioning might be off.
        Avoid medical advice. Keep it concise.
        """
    }

    private func renderMetadata(_ ctx: PlateContext) -> String {
        var lines: [String] = []
        lines.append("Metadata:")
        lines.append("- label: \(ctx.label)")
        lines.append("- confidence: \(String(format: "%.2f", ctx.confidence))")
        lines.append("- volume_ml: \(Int(ctx.volumeML))")
        lines.append("- mass_g_est: \(Int(ctx.massG))")
        if ctx.calories > 0 || ctx.protein + ctx.carbs + ctx.fat > 0 {
            lines.append("- rough_macros: P\(ctx.protein)g C\(ctx.carbs)g F\(ctx.fat)g, \(ctx.calories) kcal")
        }
        if let m = ctx.method { lines.append("- method: \(m)") }
        if let d = ctx.device { lines.append("- device: \(d)") }
        if let s = ctx.planeStableScore { lines.append("- plane_stability: \(String(format: "%.2f", s))") }

        // Add detected food items information
        if let items = ctx.detectedItems, !items.isEmpty {
            lines.append("\nDetected Food Items:")
            for (index, item) in items.enumerated() {
                lines.append("- \(index + 1). \(item.name) (conf: \(String(format: "%.2f", item.confidence)))")
                lines.append("  bbox: \(Int(item.boundingBox.x)),\(Int(item.boundingBox.y)) \(Int(item.boundingBox.width))x\(Int(item.boundingBox.height))")
                if let pixelCount = item.pixelCount {
                    lines.append("  pixels: \(pixelCount)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Image

    private func optimizeImageForAPI(_ image: UIImage) -> UIImage {
        // Resize longest side to 1024 px
        let maxDim: CGFloat = 1024
        let size = image.size
        let scale = min(maxDim / max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return out ?? image
    }
}

// MARK: - Utilities

private func sanitizeJSONText(_ text: String) -> String {
    var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
    // strip ```json fences
    if s.hasPrefix("```") {
        s = s.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    // grab first {...} block if model wrapped it
    if !s.hasPrefix("{"), let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}") {
        s = String(s[first...last])
    }
    // trim trailing after last brace
    if !s.hasSuffix("}"), let last = s.lastIndex(of: "}") {
        s = String(s[...last])
    }
    return s
}

private func redactBody(_ body: [String: Any]) -> [String: Any] {
    // Remove base64 payload when logging
    var copy = body
    if var msgs = copy["messages"] as? [[String: Any]], !msgs.isEmpty {
        var m0 = msgs[0]
        if var content = m0["content"] as? [[String: Any]] {
            for i in 0..<content.count {
                if content[i]["type"] as? String == "image_url",
                   var urlObj = content[i]["image_url"] as? [String: String],
                   urlObj["url"]?.hasPrefix("data:image/jpeg;base64,") == true {
                    urlObj["url"] = "data:image/jpeg;base64,[REDACTED]"
                    content[i]["image_url"] = urlObj
                }
            }
            m0["content"] = content
        }
        msgs[0] = m0
        copy["messages"] = msgs
    }
    return copy
}
