import SwiftUI

struct AddPartView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: InventoryViewModel
    
    @State private var partName: String = ""
    @State private var vehicleCategory: String = "Car"
    @State private var categoryDescription: String = ""
    @State private var supplier: String = ""
    @State private var quantity: Int = 1
    @State private var costPerUnitText: String = ""
    @State private var sku: String = ""
    @State private var location: String = ""
    
    let categories = ["Car", "Truck", "Bike", "Bus"]
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
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
                    Stepper(value: $quantity, in: 0...10000) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            Text("\(quantity)")
                                .foregroundColor(quantityColor(for: quantity))
                                .fontWeight(.bold)
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
            .navigationTitle("Add New Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await savePart()
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
    
    private func savePart() async {
        isSaving = true
        errorMessage = nil
        
        let cost = Double(costPerUnitText.replacingOccurrences(of: ",", with: "."))
        
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
}
