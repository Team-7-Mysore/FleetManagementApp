import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AddPartView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: InventoryViewModel
    
    @State private var partName: String
    @State private var vehicleCategory: String = "Car"
    @State private var categoryDescription: String = ""
    @State private var supplier: String = ""
    @State private var quantityText: String
    @State private var costPerUnitText: String = ""
    @State private var sku: String = ""
    @State private var location: String = ""
    
    // Image Selection State
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedUIImage: UIImage?
    @State private var isUploadingImage = false
    
    // Picker Visibility State
    @State private var isShowingOptions = false
    @State private var isShowingPhotosPicker = false
    @State private var isShowingFileImporter = false
    
    init(viewModel: InventoryViewModel, prefilledName: String? = nil, prefilledQuantity: Int? = nil, prefilledCost: Double? = nil) {
        self.viewModel = viewModel
        self._partName = State(initialValue: prefilledName ?? "")
        if let pq = prefilledQuantity, pq > 0 {
            self._quantityText = State(initialValue: "\(pq)")
        } else {
            self._quantityText = State(initialValue: "1")
        }
        
        if let cost = prefilledCost {
            self._costPerUnitText = State(initialValue: String(format: "%.2f", cost))
        } else {
            self._costPerUnitText = State(initialValue: "")
        }
    }
    
    let categories = ["Car", "Truck", "Bike", "Bus"]
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    // Duplicate Handling State
    @State private var showDuplicateAlert = false
    @State private var duplicateItem: InventoryItem?
    
    var body: some View {
        Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Button {
                                isShowingOptions = true
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 140, height: 140)
                                    
                                    if let image = selectedUIImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 140, height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 24))
                                    } else {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.white)
                                    }
                                    
                                    if isUploadingImage {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 24)
                                                .fill(Color.black.opacity(0.3))
                                            ProgressView()
                                                .tint(.white)
                                        }
                                        .frame(width: 140, height: 140)
                                    }
                                }
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                            
                            Text(selectedUIImage == nil ? "Set Part Photo" : "Change Photo")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .listRowBackground(Color.clear)
                }
                .confirmationDialog("Upload Photo", isPresented: $isShowingOptions) {
                    Button("Choose from Gallery") { isShowingPhotosPicker = true }
                    Button("Choose from Files") { isShowingFileImporter = true }
                    Button("Cancel", role: .cancel) { }
                }
                .photosPicker(isPresented: $isShowingPhotosPicker, selection: $selectedItem, matching: .images)
                .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.image]) { result in
                    switch result {
                    case .success(let url):
                        if url.startAccessingSecurityScopedResource() {
                            defer { url.stopAccessingSecurityScopedResource() }
                            if let data = try? Data(contentsOf: url),
                               let image = UIImage(data: data) {
                                withAnimation {
                                    selectedUIImage = image
                                }
                            }
                        }
                    case .failure(let error):
                        print("❌ File Import Error: \(error.localizedDescription)")
                    }
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                withAnimation {
                                    selectedUIImage = image
                                }
                            }
                        }
                    }
                }
                
                Section("Basic Information") {
                    TextField("Part Name", text: $partName)
                    
                    Picker("Category", selection: $vehicleCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("Category Description (Optional)", text: $categoryDescription)
                }
                
                Section("Inventory Details") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("1", text: $quantityText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(quantityColor(for: Int(quantityText) ?? 0))
                            .fontWeight(.bold)
                            .onChange(of: quantityText) { newValue in
                                // Only allow numbers
                                let filtered = newValue.filter { "0123456789".contains($0) }
                                if filtered != newValue {
                                    quantityText = filtered
                                }
                            }
                    }
                    
                    HStack {
                        Text("Cost per Unit (₹)")
                        Spacer()
                        TextField("0.00", text: $costPerUnitText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    TextField("SKU (Auto-generates if empty)", text: $sku)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    
                    TextField("Location (e.g. Shelf A-3)", text: $location)
                    
                    TextField("Supplier", text: $supplier)
                }
            }
            .hideKeyboardOnTap()
            .navigationTitle("Add New Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await checkAndSave()
                        }
                    }
                    .disabled(partName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .overlay {
                        if isSaving {
                            ProgressView()
                                .padding(.leading, 40)
                        }
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .alert("Duplicate Part Found", isPresented: $showDuplicateAlert) {
                Button("Combine") {
                    Task {
                        await combineWithExisting()
                    }
                }
                Button("Rename", role: .none) { }
                Button("Cancel", role: .destructive) { }
            } message: {
                if let item = duplicateItem {
                    Text("A part named '\(item.partName)' already exists in \(item.vehicleCategory ?? ""). Choose to combine quantities or rename this part.")
                }
            }
    }
    
    private func quantityColor(for quantity: Int) -> Color {
        if quantity == 0 {
            return .red
        } else if quantity <= 10 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func checkAndSave() async {
        isSaving = true
        errorMessage = nil
        
        let trimmedName = partName.trimmingCharacters(in: .whitespaces)
        
        // 1. Check for duplicates
        if let duplicate = await viewModel.checkForDuplicate(name: trimmedName, category: vehicleCategory) {
            self.duplicateItem = duplicate
            self.showDuplicateAlert = true
            self.isSaving = false
            return
        }
        
        // 2. Perform regular save if no duplicate
        await performSave()
    }
    
    private func performSave() async {
        isSaving = true
        
        let cost = Double(costPerUnitText.replacingOccurrences(of: ",", with: "."))
        let quantity = Int(quantityText) ?? 1
        
        // Auto-generate SKU if empty
        let trimmedSKU = sku.trimmingCharacters(in: .whitespaces)
        let finalSKU = trimmedSKU.isEmpty ? String(UUID().uuidString.prefix(8).uppercased()) : trimmedSKU
        
        let catDesc = categoryDescription.trimmingCharacters(in: .whitespaces)
        let finalCatDesc = catDesc.isEmpty ? "" : catDesc
        
        var uploadedImageUrl: String? = nil
        
        do {
            // Handle image upload if selected
            if let image = selectedUIImage, let data = image.jpegData(compressionQuality: 0.8) {
                isUploadingImage = true
                let fileName = "\(UUID().uuidString).jpg"
                uploadedImageUrl = try await viewModel.uploadImage(data: data, fileName: fileName)
                isUploadingImage = false
            }
            
            try await viewModel.addInventoryItem(
                partName: partName.trimmingCharacters(in: .whitespaces),
                vehicleCategory: vehicleCategory,
                categoryDescription: finalCatDesc,
                supplier: supplier.trimmingCharacters(in: .whitespaces),
                quantity: quantity,
                costPerUnit: cost,
                sku: finalSKU,
                location: location.trimmingCharacters(in: .whitespaces),
                imageUrl: uploadedImageUrl
            )
            isSaving = false
            dismiss()
        } catch {
            isSaving = false
            isUploadingImage = false
            errorMessage = error.localizedDescription
        }
    }
    
    private func combineWithExisting() async {
        guard let item = duplicateItem else { return }
        isSaving = true
        
        let addedQuantity = Int(quantityText) ?? 1
        
        do {
            try await viewModel.combineInventoryItem(id: item.inventoryId, additionalQuantity: addedQuantity)
            isSaving = false
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}
