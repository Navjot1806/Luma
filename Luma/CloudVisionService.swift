//
//  CloudVisionService.swift
//  Luma
//
//  Uses Google Cloud Vision API for object detection and product search
//

import UIKit

struct CloudVisionService {

    // MARK: - Configuration
    // API Key is stored securely in Config.swift
    // Get one from: https://console.cloud.google.com/apis/credentials
    static let apiKey = Config.googleCloudVisionAPIKey
    static let visionAPIURL = "https://vision.googleapis.com/v1/images:annotate"
    
    // MARK: - Response Models
    struct VisionResponse: Codable {
        let responses: [AnnotateImageResponse]
    }
    
    struct AnnotateImageResponse: Codable {
        let labelAnnotations: [LabelAnnotation]?
        let webDetection: WebDetection?
    }
    
    struct LabelAnnotation: Codable {
        let description: String
        let score: Float
    }
    
    struct WebDetection: Codable {
        let webEntities: [WebEntity]?
        let visuallySimilarImages: [WebImage]?
        let pagesWithMatchingImages: [WebPage]?
    }
    
    struct WebEntity: Codable {
        let entityId: String?
        let score: Float?
        let description: String?
    }
    
    struct WebImage: Codable {
        let url: String
        let score: Float?
    }
    
    struct WebPage: Codable {
        let url: String
        let pageTitle: String?
        let score: Float?
    }
    
    // MARK: - Detection Result
    struct DetectionResult {
        let mainLabel: String
        let confidence: Float
        let allLabels: [String]
        let shoppingLinks: [ShoppingLink]
        let isProduct: Bool
    }
    
    struct ShoppingLink: Identifiable {
        let id = UUID()
        let title: String
        let url: String
        let source: String
    }
    
    // MARK: - Main Detection Function
    static func detectObject(image: UIImage) async throws -> DetectionResult {
        // 1. Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "CloudVisionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        let base64Image = imageData.base64EncodedString()
        
        // 2. Build request
        let requestBody: [String: Any] = [
            "requests": [
                [
                    "image": ["content": base64Image],
                    "features": [
                        ["type": "LABEL_DETECTION", "maxResults": 10],
                        ["type": "WEB_DETECTION", "maxResults": 10],
                        ["type": "OBJECT_LOCALIZATION", "maxResults": 5]
                    ]
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw NSError(domain: "CloudVisionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])
        }
        
        // 3. Make API call
        guard let url = URL(string: "\(visionAPIURL)?key=\(apiKey)") else {
            throw NSError(domain: "CloudVisionService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "CloudVisionService", code: 4, userInfo: [NSLocalizedDescriptionKey: "API request failed"])
        }
        
        // 4. Parse response
        let visionResponse = try JSONDecoder().decode(VisionResponse.self, from: data)
        
        guard let firstResponse = visionResponse.responses.first else {
            throw NSError(domain: "CloudVisionService", code: 5, userInfo: [NSLocalizedDescriptionKey: "No results"])
        }
        
        // 5. Extract labels
        let labels = firstResponse.labelAnnotations ?? []
        let mainLabel = labels.first?.description ?? "Unknown"
        let confidence = labels.first?.score ?? 0.0
        let allLabels = labels.prefix(5).map { $0.description }
        
        // 6. Extract shopping links
        var shoppingLinks: [ShoppingLink] = []
        var isProduct = false
        
        if let webDetection = firstResponse.webDetection {
            // Check if it's a known product
            if let entities = webDetection.webEntities, !entities.isEmpty {
                isProduct = entities.contains { entity in
                    (entity.description?.lowercased().contains("product") ?? false) ||
                    (entity.description?.lowercased().contains("buy") ?? false)
                }
            }
            
            // Extract shopping pages
            if let pages = webDetection.pagesWithMatchingImages {
                shoppingLinks = pages.prefix(5).compactMap { page in
                    guard let title = page.pageTitle, !title.isEmpty else { return nil }
                    
                    // Detect shopping sites
                    let url = page.url.lowercased()
                    var source = "Web"
                    
                    if url.contains("amazon") { source = "Amazon" }
                    else if url.contains("ebay") { source = "eBay" }
                    else if url.contains("walmart") { source = "Walmart" }
                    else if url.contains("target") { source = "Target" }
                    else if url.contains("etsy") { source = "Etsy" }
                    else if url.contains("aliexpress") { source = "AliExpress" }
                    
                    return ShoppingLink(title: title, url: page.url, source: source)
                }
            }
        }
        
        print("🔍 Vision API Results:")
        print("  Main: \(mainLabel) (\(Int(confidence * 100))%)")
        print("  All: \(allLabels.joined(separator: ", "))")
        print("  Shopping links: \(shoppingLinks.count)")
        print("  Is product: \(isProduct)")
        
        return DetectionResult(
            mainLabel: mainLabel,
            confidence: confidence,
            allLabels: allLabels,
            shoppingLinks: shoppingLinks,
            isProduct: isProduct
        )
    }
    
    // MARK: - Helper: Generate Google Shopping Search URL
    static func googleShoppingURL(for query: String) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.google.com/search?tbm=shop&q=\(encodedQuery)")
    }
}
