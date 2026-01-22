//
//  ScanHistory.swift
//  Luma
//
//  Created by Navjyotsingh Multani on 1/12/26.
//

import SwiftUI
import SwiftData
import Foundation

@Model
final class ScanHistory {
    var id: UUID
    var objectName: String
    var confidence: Float
    var isProduct: Bool
    var timestamp: Date
    var allLabels: [String]
    var shoppingURL: String?
    
    // For UI display
    var dotColor: String // "blue" or "purple"
    
    init(objectName: String, confidence: Float, isProduct: Bool, allLabels: [String] = [], shoppingURL: String? = nil) {
        self.id = UUID()
        self.objectName = objectName
        self.confidence = confidence
        self.isProduct = isProduct
        self.timestamp = Date()
        self.allLabels = allLabels
        self.shoppingURL = shoppingURL
        self.dotColor = isProduct ? "purple" : "blue"
    }
    
    // Computed property for formatted date
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
