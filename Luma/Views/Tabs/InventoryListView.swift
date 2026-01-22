//
//  InventoryListView.swift
//  Luma
//
//  Advanced Search & Filter Implementation
//

import SwiftUI
import SwiftData

struct InventoryListView: View {
    // 1. Filter States
    @State private var searchText = ""
    @State private var selectedCategory: LumaCategory?
    @State private var showFilterSheet = false
    
    // Fetch categories for the filter pills
    @Query(sort: \LumaCategory.name) var categories: [LumaCategory]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Category Filter Pills
                // A horizontal scroll of "chips" to filter by category
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // "All" Pill
                        FilterPill(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            color: .gray
                        ) {
                            withAnimation { selectedCategory = nil }
                        }
                        
                        // Dynamic Category Pills
                        ForEach(categories) { category in
                            FilterPill(
                                title: category.name,
                                isSelected: selectedCategory == category,
                                color: Color(hex: category.colorHex) ?? .blue
                            ) {
                                withAnimation {
                                    // Toggle logic: if clicking selected, unselect it
                                    if selectedCategory == category {
                                        selectedCategory = nil
                                    } else {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemBackground))
                
                // MARK: - The Data List
                // We pass the filter states to the subview
                ItemListView(searchString: searchText, categoryFilter: selectedCategory)
            }
            .navigationTitle("My Luma")
            .searchable(text: $searchText, prompt: "Search items, notes...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: AddItemSheet()) { // Assuming you make AddItemSheet a view not a sheet for now, or use a .sheet modifier
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

// MARK: - Subview: The List Logic
struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [LumaItem]
    
    // FIX 1: Store the search string so the body can see it
    let searchString: String
    
    init(searchString: String, categoryFilter: LumaCategory?) {
        // FIX 2: Save the incoming value
        self.searchString = searchString
        
        let categoryName = categoryFilter?.name
        
        _items = Query(filter: #Predicate<LumaItem> { item in
            (
                searchString.isEmpty ||
                item.name.localizedStandardContains(searchString) ||
                (item.notes?.localizedStandardContains(searchString) ?? false)
            )
            &&
            (
                categoryName == nil ||
                item.category?.name == categoryName
            )
        }, sort: \LumaItem.dateAdded, order: .reverse)
    }
    
    var body: some View {
        List {
            ForEach(items) { item in
                // Placeholder navigation
                NavigationLink(destination: Text(item.name)) {
                    HStack {
                        if let data = item.thumbnailImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "cube.box.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, height: 40)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.headline)
                            if let loc = item.location {
                                Text(loc.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .overlay {
            // Now this works because 'searchString' is a property of the struct
            if items.isEmpty {
                ContentUnavailableView.search(text: searchString)
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

// MARK: - Component: Filter Pill
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary) // Adapts to Dark Mode automatically
                .clipShape(Capsule())
                .animation(.snappy, value: isSelected)
        }
    }
}

// MARK: - Helper: Hex Color
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if hexSanitized.count == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else {
            return nil
        }

        self.init(uiColor: UIColor(red: r, green: g, blue: b, alpha: a))
    }
}
