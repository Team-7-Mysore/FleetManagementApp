import SwiftUI

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
    
    init(viewModel: InventoryViewModel, prefilledName: String? = nil, prefilledQuantity: Int? = nil) {
        self.viewModel = viewModel
        self._partName = State(initialValue: prefilledName ?? "")
        if let pq = prefilledQuantity, pq > 0 {
            self._quantityText = State(initialValue: "\(pq)")
        } else {
            self._quantityText = State(initialValue: "1")
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
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        
                        Text("Upload Part Image")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
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
        
        do {
            try await viewModel.addInventoryItem(
                partName: partName.trimmingCharacters(in: .whitespaces),
                vehicleCategory: vehicleCategory,
                categoryDescription: finalCatDesc,
                supplier: supplier.trimmingCharacters(in: .whitespaces),
                quantity: quantity,
                costPerUnit: cost,
                sku: finalSKU,
                location: location.trimmingCharacters(in: .whitespaces),
                imageUrl: nil
            )
            isSaving = false
            dismiss()
        } catch {
            isSaving = false
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
