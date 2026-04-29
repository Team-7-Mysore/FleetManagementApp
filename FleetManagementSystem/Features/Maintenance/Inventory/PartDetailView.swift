import SwiftUI

struct PartDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: InventoryViewModel
    let item: InventoryItem

    @State private var isEditing = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var totalUsed = 0
    @State private var usageEntries: [InventoryViewModel.PartUsageEntry] = []
    @State private var isLoadingUsage = false
    @State private var showUsageDetails = false

    @State private var editPartName: String = ""
    @State private var editVehicleCategory: String = "Car"
    @State private var editSupplier: String = ""
    @State private var editQuantity: Int = 0
    @State private var editCostPerUnitText: String = ""
    @State private var editLocation: String = ""

    let categories = ["Car", "Truck", "Bike", "Bus"]

    private var currentItem: InventoryItem {
        viewModel.items.first(where: { $0.id == item.id }) ?? item
    }

    private var hasChanges: Bool {
        let originalCostStr = currentItem.costPerUnit != nil ? String(format: "%.2f", currentItem.costPerUnit!) : ""
        return editPartName != currentItem.partName ||
            editVehicleCategory != (currentItem.vehicleCategory ?? "Car") ||
            editSupplier != (currentItem.supplier ?? "") ||
            editQuantity != currentItem.quantity ||
            editCostPerUnitText != originalCostStr ||
            editLocation != (currentItem.location ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(width: 120, height: 120)

                    if let urlString = currentItem.imageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 24)

                if isEditing {
                    VStack(spacing: 12) {
                        TextField("Part Name", text: $editPartName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        Text("SKU: \(currentItem.sku ?? "N/A")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 6) {
                        Text(currentItem.partName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("SKU: \(currentItem.sku ?? "N/A")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 16) {
                    infoCard(title: "Stock Quantity", value: isEditing ? "" : "\(currentItem.quantity)", isEditing: isEditing) {
                        if isEditing {
                            TextField("Quantity", value: $editQuantity, format: .number)
                                .keyboardType(.numberPad)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.leading)
                                .onChange(of: editQuantity) { newValue in
                                    if newValue < 0 {
                                        editQuantity = 0
                                    }
                                }
                        }
                    }

                    infoCard(title: "Storage Location", value: isEditing ? "" : (currentItem.location ?? "Not Set"), isEditing: isEditing) {
                        if isEditing {
                            TextField("Location", text: $editLocation)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(.horizontal)

                totalUsedCard
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    detailRow(title: "Vehicle Category", isEditing: isEditing) {
                        if isEditing {
                            Picker("Category", selection: $editVehicleCategory) {
                                ForEach(categories, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        } else {
                            Text(currentItem.vehicleCategory ?? "Not Set")
                                .foregroundColor(.primary)
                        }
                    }
                    Divider().padding(.leading, 16)

                    detailRow(title: "Supplier", isEditing: isEditing) {
                        if isEditing {
                            TextField("Supplier Name", text: $editSupplier)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text(currentItem.supplier ?? "Unknown")
                                .foregroundColor(.primary)
                        }
                    }
                    Divider().padding(.leading, 16)

                    detailRow(title: "Cost per Unit", isEditing: isEditing) {
                        if isEditing {
                            TextField("0.00", text: $editCostPerUnitText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        } else if let cost = currentItem.costPerUnit {
                            Text(cost.formattedAsRupee())
                                .foregroundColor(.primary)
                        } else {
                            Text("N/A")
                                .foregroundColor(.primary)
                        }
                    }
                    Divider().padding(.leading, 16)

                    detailRow(title: "Minimum Required", isEditing: false) {
                        Text("10")
                            .foregroundColor(.primary)
                    }
                    Divider().padding(.leading, 16)

                    detailRow(title: "Last Updated", isEditing: false) {
                        if let date = currentItem.updatedAt {
                            Text(date, style: .date)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Recently")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.bottom, 30)
        }
        .hideKeyboardOnTap()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Part Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !isEditing {
                    Button("Close") {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if isSaving {
                    ProgressView()
                } else if isEditing {
                    if hasChanges {
                        Button("Save") {
                            Task { await saveChanges() }
                        }
                        .fontWeight(.bold)
                        .disabled(editPartName.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        Button("Cancel") {
                            withAnimation {
                                isEditing = false
                            }
                        }
                    }
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
        }
        .task(id: currentItem.inventoryId) {
            await loadPartUsage()
        }
        .sheet(isPresented: $showUsageDetails) {
            PartUsageDetailView(entries: usageEntries)
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

    private var totalUsedCard: some View {
        Button {
            showUsageDetails = true
        } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Used")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    if isLoadingUsage {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("\(totalUsed)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isLoadingUsage)
    }

    private func infoCard<Content: View>(title: String, value: String, isEditing: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)

            if isEditing {
                content()
            } else {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func detailRow<Content: View>(title: String, isEditing: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            content()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    private func startEditing() {
        let item = currentItem
        editPartName = item.partName
        editVehicleCategory = item.vehicleCategory ?? "Car"
        editSupplier = item.supplier ?? ""
        editQuantity = item.quantity
        editCostPerUnitText = item.costPerUnit != nil ? String(format: "%.2f", item.costPerUnit!) : ""
        editLocation = item.location ?? ""
        withAnimation {
            isEditing = true
        }
    }

    private func saveChanges() async {
        isSaving = true
        errorMessage = nil
        do {
            let costText = editCostPerUnitText.replacingOccurrences(of: ",", with: ".")
            let cost = Double(costText)
            try await viewModel.updateInventoryItem(
                id: currentItem.id,
                partName: editPartName.trimmingCharacters(in: .whitespaces),
                vehicleCategory: editVehicleCategory,
                supplier: editSupplier.trimmingCharacters(in: .whitespaces),
                quantity: editQuantity,
                costPerUnit: cost,
                location: editLocation.trimmingCharacters(in: .whitespaces)
            )
            withAnimation {
                isEditing = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func loadPartUsage() async {
        isLoadingUsage = true
        do {
            let summary = try await viewModel.fetchPartUsage(for: currentItem.inventoryId)
            totalUsed = summary.totalUsed
            usageEntries = summary.entries
        } catch {
            totalUsed = 0
            usageEntries = []
            errorMessage = error.localizedDescription
        }
        isLoadingUsage = false
    }
}

private struct PartUsageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [InventoryViewModel.PartUsageEntry]

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No usage found")
                                .font(.headline)
                            Text("This part has not been used in any work orders yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(entry.vehicleName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("Qty \(entry.quantityUsed)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }

                                if let vehicleNumber = entry.vehicleNumber, !vehicleNumber.isEmpty {
                                    Text(vehicleNumber)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text(entry.workOrderReference)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(hex: "#A3352A"))

                                    Spacer()

                                    if let usedAt = entry.usedAt {
                                        Text(usedAt, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Part Usage")
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
