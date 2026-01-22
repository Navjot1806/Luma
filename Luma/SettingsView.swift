//
//  SettingsView.swift
//  Luma
//
//  Created by Navjyotsingh Multani on 1/12/26.
//

//
//  SettingsView.swift
//  Luma
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("useCloudAPI") private var useCloudAPI = false
    @AppStorage("autoZoomEnabled") private var autoZoomEnabled = true
    @AppStorage("zoomLevel") private var zoomLevel = 2.0
    @AppStorage("saveHistory") private var saveHistory = true
    @AppStorage("showConfidence") private var showConfidence = true
    
    var body: some View {
        NavigationView {
            Form {
                // Detection Settings
                Section {
                    Toggle(isOn: $useCloudAPI) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cloud AI Detection")
                                .font(.body)
                            Text("More accurate, uses API quota")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !useCloudAPI {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Using free local detection")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Detection Method")
                } footer: {
                    Text("Cloud AI provides better accuracy and shopping links but uses your API quota. Local detection is free and works offline.")
                }
                
                // Zoom Settings
                Section {
                    Toggle(isOn: $autoZoomEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-Zoom on Scan")
                                .font(.body)
                            Text("Zooms in for better object recognition")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if autoZoomEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Zoom Level")
                                Spacer()
                                Text("\(String(format: "%.1f", zoomLevel))x")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $zoomLevel, in: 1.5...4.0, step: 0.5)
                        }
                    }
                } header: {
                    Text("Camera Zoom")
                } footer: {
                    Text("Higher zoom helps identify small objects and text more accurately.")
                }
                
                // History Settings
                Section {
                    Toggle(isOn: $saveHistory) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Save Scan History")
                                .font(.body)
                            Text("Keep track of detected objects")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        ScanHistoryView()
                    } label: {
                        HStack {
                            Text("View History")
                            Spacer()
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Scan History")
                }
                
                // Display Settings
                Section {
                    Toggle(isOn: $showConfidence) {
                        Text("Show Confidence Score")
                    }
                } header: {
                    Text("Display")
                }
                
                // API Info
                if useCloudAPI {
                    Section {
                        HStack {
                            Text("API Status")
                            Spacer()
                            if CloudVisionService.apiKey.contains("YOUR_") {
                                Label("Not Configured", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                            } else {
                                Label("Active", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Link(destination: URL(string: "https://console.cloud.google.com/")!) {
                            HStack {
                                Text("Manage API Key")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                        }
                    } header: {
                        Text("API Configuration")
                    }
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Detection Mode")
                        Spacer()
                        Text(useCloudAPI ? "Cloud" : "Local")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
}
