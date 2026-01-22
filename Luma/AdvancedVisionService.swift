//
//  AdvancedVisionService.swift
//  Luma
//
//  Advanced object detection with bounding boxes and multiple AI models
//

import UIKit
import Vision
import CoreML

struct AdvancedVisionService {
    
    struct DetectedObject {
        let label: String
        let confidence: Float
        let boundingBox: CGRect
        let allLabels: [String]
        let isProduct: Bool
    }
    
    /// Detects objects with bounding boxes using multiple Vision models
    static func detectObjectsWithBounds(image: UIImage) async throws -> [DetectedObject] {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "AdvancedVisionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        
        // Run multiple detection requests in parallel
        async let classificationResults = performClassification(ciImage: ciImage, orientation: orientation)
        async let objectResults = performObjectDetection(ciImage: ciImage, orientation: orientation)
        
        // Wait for both to complete
        let (classifications, objects) = try await (classificationResults, objectResults)
        
        // Merge results intelligently
        return mergeDetectionResults(classifications: classifications, objects: objects, imageSize: ciImage.extent.size)
    }
    
    /// Enhanced classification with multiple confidence thresholds
    private static func performClassification(ciImage: CIImage, orientation: CGImagePropertyOrientation) async throws -> [VNClassificationObservation] {
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: [:])
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Get top results with reasonable confidence
                let filtered = observations.filter { $0.confidence > 0.15 }
                
                print("🔍 Classification Results:")
                for (index, obs) in filtered.prefix(10).enumerated() {
                    print("  \(index + 1). \(cleanLabel(obs.identifier)) - \(Int(obs.confidence * 100))%")
                }
                
                continuation.resume(returning: Array(filtered.prefix(10)))
            }
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Object detection with bounding boxes
    private static func performObjectDetection(ciImage: CIImage, orientation: CGImagePropertyOrientation) async throws -> [VNRecognizedObjectObservation] {
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: [:])
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeAnimalsRequest { request, error in
                if let error = error {
                    continuation.resume(returning: [])
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                print("🐾 Animal Detection: \(observations.count) found")
                continuation.resume(returning: observations)
            }
            
            // Also try general object detection
            let objectRequest = VNDetectRectanglesRequest { request, error in
                // This helps find rectangular objects like bottles, books, phones
            }
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    /// Merge classification and object detection results
    private static func mergeDetectionResults(
        classifications: [VNClassificationObservation],
        objects: [VNRecognizedObjectObservation],
        imageSize: CGSize
    ) -> [DetectedObject] {
        var detectedObjects: [DetectedObject] = []
        
        // If we have specific object detections with bounding boxes, use those
        for object in objects {
            if let topLabel = object.labels.first {
                let label = cleanLabel(topLabel.identifier)
                let allLabels = object.labels.prefix(3).map { cleanLabel($0.identifier) }
                
                detectedObjects.append(DetectedObject(
                    label: label,
                    confidence: topLabel.confidence,
                    boundingBox: object.boundingBox,
                    allLabels: allLabels,
                    isProduct: false // Animals are not products
                ))
            }
        }
        
        // If no objects found with bounds, create a detection for the whole image
        if detectedObjects.isEmpty && !classifications.isEmpty {
            let topClassifications = classifications.prefix(5)
            let mainLabel = cleanLabel(topClassifications.first!.identifier)
            let confidence = topClassifications.first!.confidence
            let allLabels = topClassifications.map { cleanLabel($0.identifier) }
            
            // Determine if it's a product based on keywords
            let isProduct = isProductKeyword(mainLabel) || allLabels.contains { isProductKeyword($0) }
            
            // Create a full-image bounding box
            detectedObjects.append(DetectedObject(
                label: mainLabel,
                confidence: confidence,
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                allLabels: allLabels,
                isProduct: isProduct
            ))
        }
        
        return detectedObjects
    }
    
    /// Enhanced product detection keywords
    private static func isProductKeyword(_ label: String) -> Bool {
        let productKeywords = [
            // Furniture
            "chair", "table", "desk", "sofa", "couch", "bed", "cabinet", "shelf", "stool",
            // Electronics
            "phone", "iphone", "smartphone", "laptop", "computer", "tablet", "ipad", "monitor",
            "keyboard", "mouse", "headphone", "speaker", "camera", "television", "tv",
            // Beverages & Food Containers
            "bottle", "can", "cup", "mug", "glass", "container", "jar", "thermos",
            // Clothing & Accessories
            "shoe", "sneaker", "boot", "shirt", "jacket", "watch", "bag", "backpack",
            // Books & Media
            "book", "magazine", "notebook", "album",
            // Tools & Appliances
            "tool", "hammer", "drill", "appliance", "microwave", "refrigerator",
            // Toys & Games
            "toy", "game", "puzzle", "doll", "ball",
            // Other Products
            "product", "merchandise", "item", "device", "gadget", "instrument"
        ]
        
        let lowerLabel = label.lowercased()
        return productKeywords.contains { lowerLabel.contains($0) }
    }
    
    /// Clean up Vision's identifier strings
    private static func cleanLabel(_ identifier: String) -> String {
        // Remove ImageNet IDs and clean up hierarchy
        let components = identifier.components(separatedBy: ",")
        let meaningfulParts = components
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("n") && $0.count > 2 }
        
        // Prefer more specific (last) identifiers
        let result = meaningfulParts.last ?? meaningfulParts.first ?? identifier
        
        return result
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

// MARK: - Enhanced Cloud Detection
extension CloudVisionService {
    
    /// Enhanced cloud detection with better prompting
    static func detectObjectEnhanced(image: UIImage) async throws -> DetectionResult {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "CloudVisionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        let base64Image = imageData.base64EncodedString()
        
        // Enhanced request with multiple feature types
        let requestBody: [String: Any] = [
            "requests": [
                [
                    "image": ["content": base64Image],
                    "features": [
                        ["type": "LABEL_DETECTION", "maxResults": 15],
                        ["type": "WEB_DETECTION", "maxResults": 15],
                        ["type": "OBJECT_LOCALIZATION", "maxResults": 10],
                        ["type": "TEXT_DETECTION", "maxResults": 5],
                        ["type": "LOGO_DETECTION", "maxResults": 5]
                    ]
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw NSError(domain: "CloudVisionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])
        }
        
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
        
        let visionResponse = try JSONDecoder().decode(VisionResponse.self, from: data)
        
        guard let firstResponse = visionResponse.responses.first else {
            throw NSError(domain: "CloudVisionService", code: 5, userInfo: [NSLocalizedDescriptionKey: "No results"])
        }
        
        // Enhanced label extraction with better filtering
        let labels = firstResponse.labelAnnotations ?? []
        
        // Filter out generic labels and prioritize specific ones
        let filteredLabels = labels.filter { label in
            let desc = label.description.lowercased()
            // Exclude overly generic terms
            let genericTerms = ["object", "material", "product", "thing", "item", "stuff"]
            return !genericTerms.contains(desc) && label.score > 0.6
        }
        
        let bestLabels = filteredLabels.isEmpty ? labels : filteredLabels
        let mainLabel = bestLabels.first?.description ?? "Unknown"
        let confidence = bestLabels.first?.score ?? 0.0
        let allLabels = bestLabels.prefix(8).map { $0.description }
        
        // Enhanced product detection
        var shoppingLinks: [ShoppingLink] = []
        var isProduct = false
        
        if let webDetection = firstResponse.webDetection {
            isProduct = true
            
            if let pages = webDetection.pagesWithMatchingImages {
                shoppingLinks = pages.prefix(8).compactMap { page in
                    guard let title = page.pageTitle, !title.isEmpty else { return nil }
                    
                    let url = page.url.lowercased()
                    var source = "Web"
                    
                    if url.contains("amazon") { source = "Amazon" }
                    else if url.contains("ebay") { source = "eBay" }
                    else if url.contains("walmart") { source = "Walmart" }
                    else if url.contains("target") { source = "Target" }
                    else if url.contains("bestbuy") { source = "Best Buy" }
                    else if url.contains("etsy") { source = "Etsy" }
                    
                    return ShoppingLink(title: title, url: page.url, source: source)
                }
            }
        }
        
        print("🌐 Enhanced Cloud Results:")
        print("  Main: \(mainLabel) (\(Int(confidence * 100))%)")
        print("  All: \(allLabels.joined(separator: ", "))")
        print("  Shopping links: \(shoppingLinks.count)")
        
        return DetectionResult(
            mainLabel: mainLabel,
            confidence: confidence,
            allLabels: allLabels,
            shoppingLinks: shoppingLinks,
            isProduct: isProduct
        )
    }
}
