//import SwiftUI
//
//// MARK: - Fuel Log View
//struct FuelLogView: View {
//    let user: User
//    @StateObject private var vm: FuelLogViewModel
//
//    init(user: User) {
//        self.user = user
//        _vm = StateObject(wrappedValue: FuelLogViewModel(user: user))
//    }
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 16) {
//                // MARK: - Stats Row
//                HStack(spacing: 12) {
//                    StatCard(icon: "dollarsign.circle", title: "Total Spent",
//                             value: String(format: "$%.0f", vm.totalSpent))
//                    StatCard(icon: "fuelpump", title: "Avg $/gal",
//                             value: String(format: "$%.2f", vm.averageCost),
//                             tint: AppTheme.statusWarning)
//                }
//
//                HStack(spacing: 12) {
//                    StatCard(icon: "drop.fill", title: "Total Gallons",
//                             value: String(format: "%.0f", vm.totalGallons),
//                             tint: AppTheme.statusInfo)
//                    if let mpg = vm.estimatedMPG {
//                        StatCard(icon: "gauge.with.dots.needle.33percent", title: "Est. MPG",
//                                 value: String(format: "%.1f", mpg),
//                                 tint: AppTheme.primaryGreen)
//                    } else {
//                        StatCard(icon: "gauge.with.dots.needle.33percent", title: "Est. MPG",
//                                 value: "—", subtitle: "Need 2+ logs",
//                                 tint: .secondary)
//                    }
//                }
//
//                // MARK: - Add New Log
//                if vm.showAddForm {
//                    addFuelLogForm
//                }
//
//                // MARK: - Log History
//                VStack(alignment: .leading, spacing: 12) {
//                    HStack {
//                        AppTheme.sectionHeader("Fill-Up History")
//                        Spacer()
//                    }
//
//                    if vm.logs.isEmpty {
//                        EmptyStateView(
//                            icon: "fuelpump",
//                            title: "No Fuel Logs",
//                            message: "Tap + to log your first fill-up."
//                        )
//                    } else {
//                        ForEach(vm.logs) { log in
//                            fuelLogCard(log)
//                        }
//                    }
//                }
//            }
//            .padding(.horizontal)
//            .padding(.bottom, 20)
//        }
//        .background(AppTheme.pageBackground)
//        .navigationTitle("Fuel Log")
//        .toolbar {
//            ToolbarItem(placement: .topBarTrailing) {
//                Button {
//                    withAnimation { vm.showAddForm.toggle() }
//                } label: {
//                    Image(systemName: vm.showAddForm ? "xmark" : "plus")
//                }
//                .tint(AppTheme.primaryGreen)
//            }
//        }
//        .onAppear { vm.loadData() }
//    }
//
//    // MARK: - Add Form
//    private var addFuelLogForm: some View {
//        VStack(alignment: .leading, spacing: 14) {
//            Text("Log Fill-Up")
//                .font(.headline)
//
//            HStack(spacing: 12) {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("Gallons")
//                        .font(.caption.weight(.medium))
//                        .foregroundStyle(.secondary)
//                    TextField("0.0", text: $vm.gallons)
//                        .keyboardType(.decimalPad)
//                        .padding(12)
//                        .background(Color(.tertiarySystemGroupedBackground))
//                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                }
//
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("$/Gallon")
//                        .font(.caption.weight(.medium))
//                        .foregroundStyle(.secondary)
//                    TextField("0.00", text: $vm.costPerGallon)
//                        .keyboardType(.decimalPad)
//                        .padding(12)
//                        .background(Color(.tertiarySystemGroupedBackground))
//                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                }
//            }
//
//            VStack(alignment: .leading, spacing: 4) {
//                Text("Location")
//                    .font(.caption.weight(.medium))
//                    .foregroundStyle(.secondary)
//                TextField("Gas station name", text: $vm.location)
//                    .padding(12)
//                    .background(Color(.tertiarySystemGroupedBackground))
//                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//            }
//
//            if let g = Double(vm.gallons), let c = Double(vm.costPerGallon), g > 0, c > 0 {
//                HStack {
//                    Text("Total:")
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                    Text(String(format: "$%.2f", g * c))
//                        .font(.subheadline.weight(.bold))
//                        .foregroundStyle(AppTheme.primaryGreen)
//                }
//            }
//
//            Button { vm.addFuelLog() } label: {
//                HStack(spacing: 8) {
//                    Image(systemName: "plus.circle.fill")
//                    Text("Add Fill-Up")
//                }
//            }
//            .buttonStyle(PrimaryButtonStyle())
//            .disabled(!vm.canSubmit)
//            .opacity(vm.canSubmit ? 1 : 0.6)
//        }
//        .padding(18)
//        .cardStyle()
//        .transition(.move(edge: .top).combined(with: .opacity))
//    }
//
//    // MARK: - Log Card
//    private func fuelLogCard(_ log: FuelLog) -> some View {
//        HStack(spacing: 14) {
//            Image(systemName: "fuelpump.fill")
//                .font(.body)
//                .foregroundStyle(AppTheme.statusWarning)
//                .frame(width: 40, height: 40)
//                .background(AppTheme.statusWarning.opacity(0.1))
//                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//
//            VStack(alignment: .leading, spacing: 3) {
//                Text(log.location)
//                    .font(.subheadline.weight(.medium))
//                    .lineLimit(1)
//                HStack(spacing: 8) {
//                    Text(log.formattedGallons)
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                    Text("•")
//                        .foregroundStyle(.quaternary)
//                    Text(String(format: "$%.2f/gal", log.costPerGallon))
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
//            }
//
//            Spacer()
//
//            VStack(alignment: .trailing, spacing: 3) {
//                Text(log.formattedCost)
//                    .font(.subheadline.weight(.semibold))
//                Text(log.date.formatted(date: .abbreviated, time: .omitted))
//                    .font(.caption2)
//                    .foregroundStyle(.tertiary)
//            }
//        }
//        .padding(14)
//        .cardStyle()
//    }
//}
