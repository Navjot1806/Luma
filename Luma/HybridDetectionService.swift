//
//  HybridDetectionService.swift
//  Luma
//
//  Automatically uses Cloud API if available, falls back to local detection
//

import UIKit
import Vision

struct HybridDetectionService {
    
    // Set this to false to use free local detection instead
    static let useCloudAPI = false
    
    /// Main detection function that automatically chooses the best method
    static func detectObject(image: UIImage) async throws -> CloudVisionService.DetectionResult {

        if useCloudAPI && Config.isCloudVisionConfigured {
            // Try cloud detection
            do {
                return try await CloudVisionService.detectObject(image: image)
            } catch {
                print("⚠️ Cloud API failed, falling back to local: \(error.localizedDescription)")
                return try await localDetection(image: image)
            }
        } else {
            // Use local detection
            return try await localDetection(image: image)
        }
    }
    
    /// Local detection using Apple's Vision framework (FREE)
    private static func localDetection(image: UIImage) async throws -> CloudVisionService.DetectionResult {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "HybridDetectionService", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: [:])
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNClassificationObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: NSError(domain: "HybridDetectionService", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "No results"]))
                    return
                }
                
                // Get top results
                let topResults = observations.prefix(5)
                let mainLabel = cleanLabel(topResults.first?.identifier ?? "Unknown")
                let confidence = topResults.first?.confidence ?? 0.0
                
                let allLabels = topResults.map { cleanLabel($0.identifier) }
                
                // Check if it might be a product (heuristic)
                let productKeywords = ["furniture", "chair", "table", "lamp", "phone", "laptop",
                                     "computer", "monitor", "keyboard", "bottle", "cup", "book",
                                     "toy", "tool", "appliance", "electronics"]
                
                let isProduct = allLabels.contains { label in
                    productKeywords.contains { label.lowercased().contains($0) }
                }
                
                // Generate a Google Shopping link
                var shoppingLinks: [CloudVisionService.ShoppingLink] = []
                if isProduct {
                    if let url = CloudVisionService.googleShoppingURL(for: mainLabel) {
                        shoppingLinks.append(
                            CloudVisionService.ShoppingLink(
                                title: "Search \(mainLabel) on Google Shopping",
                                url: url.absoluteString,
                                source: "Google Shopping"
                            )
                        )
                    }
                }
                
                let result = CloudVisionService.DetectionResult(
                    mainLabel: mainLabel,
                    confidence: confidence,
                    allLabels: allLabels,
                    shoppingLinks: shoppingLinks,
                    isProduct: isProduct
                )
                
                print("🔍 Local Detection:")
                print("  Main: \(mainLabel) (\(Int(confidence * 100))%)")
                print("  All: \(allLabels.joined(separator: ", "))")
                print("  Is product: \(isProduct)")
                
                continuation.resume(returning: result)
            }
            
            // Note: VNClassifyImageRequest doesn't support imageCropAndScaleOption
            // It automatically handles image scaling internally
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Clean up Vision's identifier strings
    private static func cleanLabel(_ identifier: String) -> String {
        let components = identifier.components(separatedBy: ",")
        let meaningfulParts = components
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("n") }
        
        let result = meaningfulParts.last ?? meaningfulParts.first ?? identifier
        
        return result
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Helper Extension
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
