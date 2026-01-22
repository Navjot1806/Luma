//
//  EnhancedARWrapper.swift (With Object Highlighting)
//  Luma
//

import SwiftUI
import RealityKit
import ARKit
import SwiftData

struct EnhancedARWrapper: UIViewRepresentable {
    @Binding var selectedDetails: String?
    @Binding var detectionResult: CloudVisionService.DetectionResult?
    @Binding var showShoppingSheet: Bool
    var inventory: [LumaItem]
    
    @AppStorage("useCloudAPI") var useCloudAPI = false
    @AppStorage("autoZoomEnabled") var autoZoomEnabled = true
    @AppStorage("zoomLevel") var zoomLevel = 2.0
    @AppStorage("saveHistory") var saveHistory = true
    
    var modelContext: ModelContext
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        arView.session.run(config)
        
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.inventory = inventory
        context.coordinator.autoZoomEnabled = autoZoomEnabled
        context.coordinator.zoomLevel = zoomLevel
        context.coordinator.saveHistory = saveHistory
        context.coordinator.useCloudAPI = useCloudAPI
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, modelContext: modelContext)
    }
    
    class Coordinator: NSObject {
        var parent: EnhancedARWrapper
        weak var arView: ARView?
        var inventory: [LumaItem] = []
        var modelContext: ModelContext
        
        var autoZoomEnabled: Bool = true
        var zoomLevel: Double = 2.0
        var saveHistory: Bool = true
        var useCloudAPI: Bool = false
        
        // Store current highlight overlay
        var highlightOverlay: UIView?
        
        init(parent: EnhancedARWrapper, modelContext: ModelContext) {
            self.parent = parent
            self.modelContext = modelContext
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let tapLocation = sender.location(in: arView)
            
            // Check if tapped existing anchor
            if let entity = arView.entity(at: tapLocation) {
                parent.showShoppingSheet = true
                animatePulse(entity: entity)
                return
            }
            
            // Perform raycast for new detection
            let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .any)
            
            if let firstResult = results.first {
                detectAndHighlightObject(at: firstResult, in: arView, tapLocation: tapLocation)
            } else {
                parent.selectedDetails = "📍 Point at an object and tap"
            }
        }
        
        private func detectAndHighlightObject(at raycastResult: ARRaycastResult, in arView: ARView, tapLocation: CGPoint) {
            guard let currentFrame = arView.session.currentFrame else {
                parent.selectedDetails = "⏳ Camera initializing..."
                return
            }
            
            parent.selectedDetails = "🔍 Analyzing object..."
            
            // Show temporary highlight at tap location
            showTapHighlight(at: tapLocation, in: arView)
            
            // Get camera image
            let pixelBuffer = currentFrame.capturedImage
            
            // Process with zoom if enabled
            let processedImage: UIImage
            if autoZoomEnabled {
                processedImage = zoomAndCropImage(pixelBuffer: pixelBuffer, tapPoint: tapLocation, arView: arView)
            } else {
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                let context = CIContext()
                guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                    parent.selectedDetails = "❌ Image processing failed"
                    return
                }
                processedImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            }
            
            Task {
                do {
                    // Use enhanced detection
                    let result: CloudVisionService.DetectionResult
                    
                    if useCloudAPI && !CloudVisionService.apiKey.contains("YOUR_") {
                        // Use enhanced cloud API
                        result = try await CloudVisionService.detectObjectEnhanced(image: processedImage)
                    } else {
                        // Use local advanced detection
                        let detections = try await AdvancedVisionService.detectObjectsWithBounds(image: processedImage)
                        
                        guard let bestDetection = detections.first else {
                            await MainActor.run {
                                parent.selectedDetails = "❌ Could not identify object"
                            }
                            return
                        }
                        
                        // Convert to our result format
                        result = CloudVisionService.DetectionResult(
                            mainLabel: bestDetection.label,
                            confidence: bestDetection.confidence,
                            allLabels: bestDetection.allLabels,
                            shoppingLinks: bestDetection.isProduct ? [
                                CloudVisionService.ShoppingLink(
                                    title: "Search \(bestDetection.label) on Google Shopping",
                                    url: CloudVisionService.googleShoppingURL(for: bestDetection.label)?.absoluteString ?? "",
                                    source: "Google Shopping"
                                )
                            ] : [],
                            isProduct: bestDetection.isProduct
                        )
                    }
                    
                    await MainActor.run {
                        parent.detectionResult = result
                        
                        // Save to history
                        if saveHistory {
                            saveToHistory(result: result)
                        }
                        
                        // Place 3D marker with highlight
                        placeMarkerWithHighlight(
                            at: raycastResult,
                            in: arView,
                            result: result,
                            tapLocation: tapLocation
                        )
                        
                        // Remove temporary highlight
                        removeTapHighlight()
                    }
                } catch {
                    await MainActor.run {
                        print("❌ Detection Error: \(error.localizedDescription)")
                        parent.selectedDetails = "⚠️ Detection failed. Try again."
                        removeTapHighlight()
                    }
                }
            }
        }
        
        private func showTapHighlight(at point: CGPoint, in arView: ARView) {
            // Remove old highlight
            highlightOverlay?.removeFromSuperview()
            
            // Create pulsing circle at tap location
            let size: CGFloat = 60
            let overlay = UIView(frame: CGRect(
                x: point.x - size/2,
                y: point.y - size/2,
                width: size,
                height: size
            ))
            overlay.backgroundColor = .clear
            overlay.layer.borderColor = UIColor.systemBlue.cgColor
            overlay.layer.borderWidth = 3
            overlay.layer.cornerRadius = size/2
            overlay.alpha = 0
            
            arView.addSubview(overlay)
            highlightOverlay = overlay
            
            // Animate pulse
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
                overlay.alpha = 0.8
                overlay.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            } completion: { _ in
                UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn, .repeat, .autoreverse]) {
                    overlay.alpha = 0.4
                }
            }
        }
        
        private func removeTapHighlight() {
            UIView.animate(withDuration: 0.2) {
                self.highlightOverlay?.alpha = 0
            } completion: { _ in
                self.highlightOverlay?.removeFromSuperview()
                self.highlightOverlay = nil
            }
        }
        
        private func zoomAndCropImage(pixelBuffer: CVPixelBuffer, tapPoint: CGPoint, arView: ARView) -> UIImage {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            
            let imageSize = ciImage.extent.size
            let viewSize = arView.bounds.size
            
            let scaleX = imageSize.width / viewSize.width
            let scaleY = imageSize.height / viewSize.height
            
            let imageTapX = tapPoint.x * scaleX
            let imageTapY = tapPoint.y * scaleY
            
            let cropWidth = imageSize.width / CGFloat(zoomLevel)
            let cropHeight = imageSize.height / CGFloat(zoomLevel)
            
            let cropX = max(0, min(imageTapX - cropWidth / 2, imageSize.width - cropWidth))
            let cropY = max(0, min(imageTapY - cropHeight / 2, imageSize.height - cropHeight))
            
            let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
            let croppedImage = ciImage.cropped(to: cropRect)
            
            guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else {
                let fullCGImage = context.createCGImage(ciImage, from: ciImage.extent)!
                return UIImage(cgImage: fullCGImage, scale: 1.0, orientation: .right)
            }
            
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        }
        
        private func saveToHistory(result: CloudVisionService.DetectionResult) {
            let shoppingURL = result.shoppingLinks.first?.url
            
            let historyItem = ScanHistory(
                objectName: result.mainLabel,
                confidence: result.confidence,
                isProduct: result.isProduct,
                allLabels: Array(result.allLabels.dropFirst()),
                shoppingURL: shoppingURL
            )
            
            modelContext.insert(historyItem)
            try? modelContext.save()
        }
        
        private func placeMarkerWithHighlight(
            at raycastResult: ARRaycastResult,
            in arView: ARView,
            result: CloudVisionService.DetectionResult,
            tapLocation: CGPoint
        ) {
            // Create anchor
            let anchor = AnchorEntity(world: raycastResult.worldTransform)
            
            // Determine color based on confidence and type
            let color: UIColor
            if result.isProduct {
                color = result.confidence > 0.7 ? .systemPurple : .systemPink
            } else {
                color = result.confidence > 0.7 ? .systemBlue : .systemTeal
            }
            
            // Create glowing sphere with better visibility
            let material = SimpleMaterial(color: color, isMetallic: true)
            let mesh = MeshResource.generateSphere(radius: 0.04)
            let sphere = ModelEntity(mesh: mesh, materials: [material])
            
            // Add glow effect with a larger transparent sphere
            let glowMaterial = SimpleMaterial(color: color.withAlphaComponent(0.3), isMetallic: false)
            let glowMesh = MeshResource.generateSphere(radius: 0.08)
            let glowSphere = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
            
            sphere.addChild(glowSphere)
            
            // Store info
            let icon = result.isProduct ? "🛍️" : "🏷️"
            let confidenceText = Int(result.confidence * 100)
            sphere.name = "\(icon) \(result.mainLabel) (\(confidenceText)%)"
            sphere.generateCollisionShapes(recursive: true)
            
            // Spawn animation
            var transform = sphere.transform
            transform.scale = [0.1, 0.1, 0.1]
            sphere.transform = transform
            
            anchor.addChild(sphere)
            arView.scene.addAnchor(anchor)
            
            // Animate in
            transform.scale = [1.0, 1.0, 1.0]
            sphere.move(to: transform, relativeTo: nil, duration: 0.4, timingFunction: .easeOut)
            
            // Continuous subtle pulse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.addContinuousPulse(to: glowSphere)
            }
            
            // Update UI
            let confidence = Int(result.confidence * 100)
            let otherLabels = result.allLabels.dropFirst().prefix(2).joined(separator: ", ")
            
            if result.isProduct {
                parent.selectedDetails = "🛍️ \(result.mainLabel) (\(confidence)%)\n💡 \(otherLabels)\n🛒 Tap to shop"
            } else {
                parent.selectedDetails = "🏷️ \(result.mainLabel) (\(confidence)%)\n💡 Also: \(otherLabels)"
            }
            
            // Auto-show shopping for high-confidence products
            if result.isProduct && !result.shoppingLinks.isEmpty && result.confidence > 0.7 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.parent.showShoppingSheet = true
                }
            }
        }
        
        private func addContinuousPulse(to entity: Entity) {
            var transform = entity.transform
            transform.scale = [1.2, 1.2, 1.2]
            entity.move(to: transform, relativeTo: nil, duration: 1.0, timingFunction: .easeInOut)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                transform.scale = [1.0, 1.0, 1.0]
                entity.move(to: transform, relativeTo: nil, duration: 1.0, timingFunction: .easeInOut)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.addContinuousPulse(to: entity)
                }
            }
        }
        
        private func animatePulse(entity: Entity) {
            var transform = entity.transform
            transform.scale = [1.4, 1.4, 1.4]
            entity.move(to: transform, relativeTo: entity.parent, duration: 0.15)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                transform.scale = [1.0, 1.0, 1.0]
                entity.move(to: transform, relativeTo: entity.parent, duration: 0.15)
            }
        }
    }
}
