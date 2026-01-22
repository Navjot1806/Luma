//
//  ScanHistoryView.swift
//  Luma
//
//  Created by Navjyotsingh Multani on 1/12/26.
//

//
//  ScanHistoryView.swift
//  Luma
//

import SwiftUI
import SwiftData

struct ScanHistoryView: View {
    @Query(sort: \ScanHistory.timestamp, order: .reverse) var history: [ScanHistory]
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        Group {
            if history.isEmpty {
                ContentUnavailableView(
                    "No Scan History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Objects you scan will appear here")
                )
            } else {
                List {
                    ForEach(history) { scan in
                        ScanHistoryRow(scan: scan)
                    }
                    .onDelete(perform: deleteScans)
                }
                .toolbar {
                    if !history.isEmpty {
                        Button(role: .destructive) {
                            clearAllHistory()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Scan History")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func deleteScans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(history[index])
        }
    }
    
    private func clearAllHistory() {
        for scan in history {
            modelContext.delete(scan)
        }
    }
}

struct ScanHistoryRow: View {
    let scan: ScanHistory
    
    var body: some View {
        HStack(spacing: 12) {
            // Color dot indicator
            Circle()
                .fill(scan.dotColor == "purple" ? Color.purple : Color.blue)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(scan.objectName)
                        .font(.headline)
                    
                    if scan.isProduct {
                        Image(systemName: "cart.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
                
                HStack {
                    Text("\(Int(scan.confidence * 100))% confident")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(scan.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !scan.allLabels.isEmpty {
                    Text("Also: \(scan.allLabels.prefix(3).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let urlString = scan.shoppingURL, let url = URL(string: urlString) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        ScanHistoryView()
    }
}
