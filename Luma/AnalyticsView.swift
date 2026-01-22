//
//  AnalyticsView.swift
//  Luma
//
//  X-Ray Analytics Dashboard with Charts
//

import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Query(sort: \ScanHistory.timestamp, order: .reverse) var allScans: [ScanHistory]
    @State private var selectedTimeFrame: TimeFrame = .week
    
    enum TimeFrame: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time frame picker
                    Picker("Time Frame", selection: $selectedTimeFrame) {
                        ForEach(TimeFrame.allCases, id: \.self) { frame in
                            Text(frame.rawValue).tag(frame)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if filteredScans.isEmpty {
                        ContentUnavailableView(
                            "No Scan Data",
                            systemImage: "chart.bar.xaxis",
                            description: Text("Start scanning objects to see analytics")
                        )
                        .frame(height: 400)
                    } else {
                        // Stats Overview
                        StatsOverviewSection(scans: filteredScans)
                        
                        // Category Distribution Pie Chart
                        CategoryPieChart(scans: filteredScans)
                        
                        // Products vs Natural Objects
                        ProductsVsNaturalChart(scans: filteredScans)
                        
                        // Scan Timeline
                        ScanTimelineChart(scans: filteredScans)
                        
                        // Top Detected Objects
                        TopObjectsList(scans: filteredScans)
                        
                        // Quick Links Section
                        QuickLinksSection(scans: filteredScans)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("X-Ray Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    var filteredScans: [ScanHistory] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeFrame {
        case .day:
            return allScans.filter { calendar.isDateInToday($0.timestamp) }
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return allScans.filter { $0.timestamp >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return allScans.filter { $0.timestamp >= monthAgo }
        case .all:
            return allScans
        }
    }
}

// MARK: - Stats Overview
struct StatsOverviewSection: View {
    let scans: [ScanHistory]
    
    var totalScans: Int { scans.count }
    var productScans: Int { scans.filter { $0.isProduct }.count }
    var avgConfidence: Int {
        guard !scans.isEmpty else { return 0 }
        let total = scans.reduce(0.0) { $0 + $1.confidence }
        return Int((total / Float(scans.count)) * 100)
    }
    var uniqueObjects: Int { Set(scans.map { $0.objectName }).count }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Overview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 12)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Total Scans", value: "\(totalScans)", icon: "camera.viewfinder", color: .blue)
                StatCard(title: "Products Found", value: "\(productScans)", icon: "cart.fill", color: .purple)
                StatCard(title: "Avg Confidence", value: "\(avgConfidence)%", icon: "checkmark.circle.fill", color: .green)
                StatCard(title: "Unique Objects", value: "\(uniqueObjects)", icon: "sparkles", color: .orange)
            }
            .padding(.horizontal)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Category Pie Chart
struct CategoryPieChart: View {
    let scans: [ScanHistory]
    
    var categoryData: [(name: String, count: Int, color: Color)] {
        let grouped = Dictionary(grouping: scans) { scan -> String in
            // Categorize based on common keywords
            let name = scan.objectName.lowercased()
            if name.contains("furniture") || name.contains("chair") || name.contains("table") || name.contains("desk") {
                return "Furniture"
            } else if name.contains("electronic") || name.contains("phone") || name.contains("laptop") || name.contains("computer") {
                return "Electronics"
            } else if name.contains("bottle") || name.contains("cup") || name.contains("container") || name.contains("drink") {
                return "Beverages"
            } else if name.contains("book") || name.contains("paper") || name.contains("document") {
                return "Documents"
            } else if name.contains("tree") || name.contains("plant") || name.contains("flower") {
                return "Nature"
            } else if name.contains("person") || name.contains("face") || name.contains("human") {
                return "People"
            } else if name.contains("sky") || name.contains("cloud") || name.contains("building") {
                return "Environment"
            } else {
                return "Other"
            }
        }
        
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .red, .yellow, .cyan]
        
        return grouped.map { (name: $0.key, count: $0.value.count, color: colors[abs($0.key.hashValue) % colors.count]) }
            .sorted { $0.count > $1.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan Categories")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart(categoryData, id: \.name) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.color)
                    .annotation(position: .overlay) {
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(height: 250)
                .padding()
                
                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(categoryData, id: \.name) { item in
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            Text(item.name)
                                .font(.caption)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                // Fallback for iOS 15
                VStack {
                    ForEach(categoryData, id: \.name) { item in
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 12, height: 12)
                            Text(item.name)
                            Spacer()
                            Text("\(item.count)")
                                .fontWeight(.bold)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Products vs Natural Chart
struct ProductsVsNaturalChart: View {
    let scans: [ScanHistory]
    
    var data: [(type: String, count: Int, color: Color)] {
        let products = scans.filter { $0.isProduct }.count
        let natural = scans.count - products
        return [
            (type: "Products", count: products, color: .purple),
            (type: "Natural", count: natural, color: .blue)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Object Types")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart(data, id: \.type) { item in
                    BarMark(
                        x: .value("Type", item.type),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(item.color)
                    .annotation(position: .top) {
                        Text("\(item.count)")
                            .font(.caption.bold())
                    }
                }
                .frame(height: 200)
                .padding()
            } else {
                HStack(spacing: 20) {
                    ForEach(data, id: \.type) { item in
                        VStack {
                            Rectangle()
                                .fill(item.color)
                                .frame(width: 80, height: CGFloat(item.count) * 3)
                            Text(item.type)
                                .font(.caption)
                            Text("\(item.count)")
                                .font(.caption.bold())
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Timeline Chart
struct ScanTimelineChart: View {
    let scans: [ScanHistory]
    
    var dailyData: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: scans) { scan in
            calendar.startOfDay(for: scan.timestamp)
        }
        
        return grouped.map { (date: $0.key, count: $0.value.count) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan Activity")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart(dailyData, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Scans", item.count)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Scans", item.count)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 200)
                .padding()
            } else {
                Text("Activity chart available on iOS 16+")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Top Objects List
struct TopObjectsList: View {
    let scans: [ScanHistory]
    
    var topObjects: [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: scans) { $0.objectName }
        return grouped.map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most Scanned Objects")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(Array(topObjects.enumerated()), id: \.element.name) { index, item in
                    HStack {
                        Text("#\(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                        
                        Text(item.name)
                            .font(.body)
                        
                        Spacer()
                        
                        Text("\(item.count)x")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Quick Links Section
struct QuickLinksSection: View {
    let scans: [ScanHistory]
    
    var recentProducts: [ScanHistory] {
        scans.filter { $0.isProduct && $0.shoppingURL != nil }
            .prefix(3)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Shopping Links")
                .font(.headline)
                .padding(.horizontal)
            
            if recentProducts.isEmpty {
                Text("No product scans yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(recentProducts) { scan in
                        if let urlString = scan.shoppingURL, let url = URL(string: urlString) {
                            Link(destination: url) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(scan.objectName)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Text("Scanned \(scan.formattedDate)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.purple)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Google search for most common object
            if !scans.isEmpty {
                let grouped = Dictionary(grouping: scans) { $0.objectName }
                if let mostCommonPair = grouped.max(by: { $0.value.count < $1.value.count }),
                   let url = CloudVisionService.googleShoppingURL(for: mostCommonPair.key) {
                    
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search '\(mostCommonPair.key)' on Google")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .padding(.vertical)
    }
}

#Preview {
    AnalyticsView()
}
