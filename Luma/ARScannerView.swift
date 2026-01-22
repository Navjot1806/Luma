//
//  ARScannerView.swift (With Shopping Links)
//  Luma
//

import SwiftUI
import SwiftData

struct ARScannerView: View {
    @State private var selectedItemInfo: String?
    @State private var detectionResult: CloudVisionService.DetectionResult?
    @State private var showShoppingSheet = false
    
    @Query var items: [LumaItem]
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        ZStack {
            EnhancedARWrapper(
                selectedDetails: $selectedItemInfo,
                detectionResult: $detectionResult,
                showShoppingSheet: $showShoppingSheet,
                inventory: items,
                modelContext: modelContext
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Luma X-Ray")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        if let result = detectionResult {
                            Text("\(Int(result.confidence * 100))% confident")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Shopping button (only for products)
                    if let result = detectionResult, result.isProduct {
                        Button {
                            showShoppingSheet = true
                        } label: {
                            Image(systemName: "cart.fill")
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.purple)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.top, 50)
                .padding(.horizontal)
                
                Spacer()
                
                // Bottom info panel
                if let info = selectedItemInfo {
                    VStack(spacing: 8) {
                        Text(info)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        if let result = detectionResult, !result.allLabels.isEmpty {
                            HStack {
                                ForEach(result.allLabels.prefix(4), id: \.self) { label in
                                    Text(label)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(8)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.bottom, 20)
                    .padding(.horizontal)
                    .animation(.easeInOut, value: selectedItemInfo)
                }
            }
        }
        .sheet(isPresented: $showShoppingSheet) {
            ShoppingLinksSheet(result: detectionResult)
        }
    }
}

// MARK: - Shopping Links Sheet
struct ShoppingLinksSheet: View {
    let result: CloudVisionService.DetectionResult?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if let result = result {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(result.mainLabel)
                                        .font(.title2.bold())
                                    Spacer()
                                    Text("\(Int(result.confidence * 100))%")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                
                                Text("Also identified as: \(result.allLabels.dropFirst().joined(separator: ", "))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // Shopping links section
                            if !result.shoppingLinks.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Where to Buy")
                                        .font(.headline)
                                    
                                    ForEach(result.shoppingLinks) { link in
                                        Link(destination: URL(string: link.url)!) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(link.title)
                                                        .font(.body)
                                                        .lineLimit(2)
                                                        .foregroundColor(.primary)
                                                    
                                                    Text(link.source)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "arrow.up.right.square")
                                                    .foregroundColor(.blue)
                                            }
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                            
                            // Google Shopping search button
                            if let searchURL = CloudVisionService.googleShoppingURL(for: result.mainLabel) {
                                Link(destination: searchURL) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                        Text("Search on Google Shopping")
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "No Detection Results",
                        systemImage: "questionmark.circle",
                        description: Text("Scan an object first")
                    )
                }
            }
            .navigationTitle("Detection Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
