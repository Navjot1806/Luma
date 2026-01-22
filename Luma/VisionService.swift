//
//  VisionService.swift
//  Luma
//
//  Handles on-device image analysis using Vision framework.
//

import Vision
import UIKit

struct VisionService {
    
    /// Analyzes an image and returns the most likely object name.
    static func classify(image: UIImage) async throws -> String? {
        // 1. Convert UIImage to CIImage (required for Vision)
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // 2. Create the request handler
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // 3. Create the request using a Continuation to bridge Async/Await with legacy callback APIs
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // 4. Process results
                guard let observations = request.results as? [VNClassificationObservation],
                      let topResult = observations.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Filter: Only return if confidence is reasonably high (> 50%)
                if topResult.confidence > 0.5 {
                    // Vision returns hierarchy like "computer -> laptop". We take the first meaningful identifier.
                    let identifier = topResult.identifier.components(separatedBy: ",").first ?? topResult.identifier
                    continuation.resume(returning: identifier.capitalized)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            // 5. Run the request
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
