//
//  DataSeeder.swift
//  Luma
//
//  Logic to populate default data on first launch.
//

import SwiftData
import Foundation

@MainActor
class DataSeeder {
    static func seedData(modelContext: ModelContext) {
        // Check if data already exists to avoid duplicates
        let descriptor = FetchDescriptor<LumaCategory>()
        let existingCount = try? modelContext.fetchCount(descriptor)
        
        if existingCount == 0 || existingCount == nil {
            createDefaults(context: modelContext)
        }
    }
    
    private static func createDefaults(context: ModelContext) {
        // 1. Default Categories
        let categories = [
            LumaCategory(name: "Electronics", colorHex: "#007AFF"), // Blue
            LumaCategory(name: "Furniture", colorHex: "#FF9500"),   // Orange
            LumaCategory(name: "Appliances", colorHex: "#FF3B30"),  // Red
            LumaCategory(name: "Tools", colorHex: "#A2845E"),       // Brown
            LumaCategory(name: "Documents", colorHex: "#8E8E93")    // Gray
        ]
        
        for cat in categories {
            context.insert(cat)
        }
        
        // 2. Default Locations
        let locations = [
            LumaLocation(name: "Living Room", iconSymbol: "sofa.fill"),
            LumaLocation(name: "Kitchen", iconSymbol: "cooktop.fill"),
            LumaLocation(name: "Garage", iconSymbol: "car.fill"),
            LumaLocation(name: "Home Office", iconSymbol: "laptopcomputer"),
            LumaLocation(name: "Bedroom", iconSymbol: "bed.double.fill")
        ]
        
        for loc in locations {
            context.insert(loc)
        }
        
        // Save is implicit in SwiftData, but helpful for debugging flow
        try? context.save()
        print("Data Seeding Complete: Defaults added.")
    }
}
