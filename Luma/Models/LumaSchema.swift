//
//  LumaSchema.swift
//  Luma
//
//  Created for Luma AR Project.
//

import SwiftUI
import SwiftData
import CoreLocation

// MARK: - Luma Item (The core object)
@Model
final class LumaItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateAdded: Date
    
    // Optional details that might be filled by user OR AI later
    var manufacturer: String?
    var modelNumber: String?
    var serialNumber: String?
    var purchaseDate: Date?
    var notes: String?
    
    // Visual Data (For the AR recognition thumb)
    @Attribute(.externalStorage) var thumbnailImageData: Data?
    
    // AI/Search Data (Competitive Feature: Future-proofing for vector search)
    // Storing high-dimensional vectors for semantic search later.
    var embeddingVector: [Double]?

    // MARK: Relationships
    
    // An item belongs to one specific location (e.g., "Garage Shelf A")
    var location: LumaLocation?
    
    // An item belongs to a broader category (e.g., "Tools")
    var category: LumaCategory?
    
    // An item can have multiple maintenance tasks (e.g., "Change filter", "Warranty expiry")
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceTask.item)
    var tasks: [MaintenanceTask]?

    init(name: String, location: LumaLocation? = nil, category: LumaCategory? = nil) {
        self.id = UUID()
        self.name = name
        self.dateAdded = Date()
        self.location = location
        self.category = category
    }
}

// MARK: - Location (Where things are spatially)
@Model
final class LumaLocation {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconSymbol: String // SF Symbol name, e.g., "garage.fill"
    
    // Competitive Feature: Rough GPS coord for broad "Where is it" queries
    var latitude: Double?
    var longitude: Double?

    @Relationship(deleteRule: .nullify, inverse: \LumaItem.location)
    var items: [LumaItem]?
    
    init(name: String, iconSymbol: String = "mappin.and.ellipse") {
        self.id = UUID()
        self.name = name
        self.iconSymbol = iconSymbol
    }
}

// MARK: - Category (For organization)
@Model
final class LumaCategory {
    @Attribute(.unique) var name: String // Using name as unique ID here for simplicity
    var colorHex: String // Storing color as hex string
    
    @Relationship(deleteRule: .nullify, inverse: \LumaItem.category)
    var items: [LumaItem]?
    
    init(name: String, colorHex: String = "#007AFF") {
        self.name = name
        self.colorHex = colorHex
    }
}

// MARK: - Maintenance Task (Actionable items)
@Model
final class MaintenanceTask {
    var title: String
    var dueDate: Date
    var isCompleted: Bool
    var priorityLevel: Int // 1 = Low, 3 = High

    // The item this task belongs to
    var item: LumaItem?
    
    init(title: String, dueDate: Date, priorityLevel: Int = 1) {
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = false
        self.priorityLevel = priorityLevel
    }
}
