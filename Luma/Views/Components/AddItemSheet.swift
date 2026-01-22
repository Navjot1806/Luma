//
//  AddItemSheet.swift (Updated)
//  Luma
//

import SwiftUI
import SwiftData

struct AddItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Form States
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var selectedLocation: LumaLocation?
    @State private var selectedCategory: LumaCategory?
    
    // Camera/Vision States
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var isAnalyzing = false
    
    // Data Sources
    @Query var locations: [LumaLocation]
    @Query var categories: [LumaCategory]

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Smart Scan Section
                Section {
                    HStack {
                        if let capturedImage {
                            Image(uiImage: capturedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.accentColor, lineWidth: 2)
                                )
                        } else {
                            Button(action: { showCamera = true }) {
                                VStack {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.largeTitle)
                                    Text("Smart Scan")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        if isAnalyzing {
                            VStack(alignment: .leading) {
                                ProgressView()
                                Text("Analyzing...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading)
                        } else if capturedImage != nil && name.isEmpty {
                            Text("Tap to retry scan")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .background(Color.clear)
                } header: {
                    Text("Capture")
                }

                // MARK: - Details
                Section(header: Text("Basic Info")) {
                    TextField("Item Name", text: $name)
                    
                    Picker("Location", selection: $selectedLocation) {
                        Text("Select Location").tag(nil as LumaLocation?)
                        ForEach(locations) { loc in
                            Text(loc.name).tag(loc as LumaLocation?)
                        }
                    }
                    
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select Category").tag(nil as LumaCategory?)
                        ForEach(categories) { cat in
                            Text(cat.name).tag(cat as LumaCategory?)
                        }
                    }
                }
                
                Section(header: Text("Details")) {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                // You will need a simple ImagePicker wrapper struct here
                ImagePicker(image: $capturedImage)
                    .ignoresSafeArea()
            }
            // Trigger analysis when image changes
            .onChange(of: capturedImage) { _, newImage in
                if let img = newImage {
                    analyzeImage(img)
                }
            }
        }
    }

    // MARK: - Logic
    
    private func analyzeImage(_ image: UIImage) {
        isAnalyzing = true
        
        Task {
            do {
                // Call our Vision Service
                if let detectedName = try await VisionService.classify(image: image) {
                    // Update UI on Main Thread
                    await MainActor.run {
                        // Only auto-fill if user hasn't typed anything
                        if name.isEmpty {
                            name = detectedName
                        }
                        // Simple heuristic: If it detects a sofa, pick Living Room
                        if detectedName.lowercased().contains("sofa") {
                            selectedLocation = locations.first(where: { $0.name == "Living Room" })
                        }
                        isAnalyzing = false
                    }
                } else {
                    await MainActor.run { isAnalyzing = false }
                }
            } catch {
                print("Vision error: \(error)")
                await MainActor.run { isAnalyzing = false }
            }
        }
    }

    private func saveItem() {
        let newItem = LumaItem(name: name, location: selectedLocation, category: selectedCategory)
        if !notes.isEmpty { newItem.notes = notes }
        if let capturedImage {
            // Compress and save image data
            newItem.thumbnailImageData = capturedImage.jpegData(compressionQuality: 0.7)
        }
        modelContext.insert(newItem)
    }
}
