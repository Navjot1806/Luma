//
//  LumaApp.swift
//  Luma
//

import SwiftUI
import SwiftData

@main
struct LumaApp: App {
    // Define the container so it's accessible throughout the app
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LumaItem.self,
            LumaLocation.self,
            LumaCategory.self,
            MaintenanceTask.self,
            ScanHistory.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // In production, handle this gracefully, don't crash.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // Inside LumaApp.swift body:
        WindowGroup {
            ContentView()
                .onAppear {
                    // Run seeder on the main actor
                    DataSeeder.seedData(modelContext: sharedModelContainer.mainContext)
                    
                }
                .tint(Color("LumaAccent"))
        }
        .modelContainer(sharedModelContainer)
    }
}
