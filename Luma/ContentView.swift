//
//  ContentView.swift
//  Luma
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .inventory

    enum Tab {
        case inventory
        case scan
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }
                .tag(Tab.inventory)
            
            ARScannerView()
                .tabItem {
                    Label("X-Ray", systemImage: "camera.viewfinder")
                }
                .tag(Tab.scan)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
    }
}

#Preview {
    ContentView()
}
