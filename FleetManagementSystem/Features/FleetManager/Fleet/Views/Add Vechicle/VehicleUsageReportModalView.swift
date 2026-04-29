import SwiftUI

struct VehicleUsageReportModalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VehicleDetailViewModel

    let onGenerate: () async -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vehicle Usage Report")
                        .font(.title2.bold())
                    Text("Generate a PDF report with trip history, distance travelled, status summary, and route details for this vehicle.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let vehicle = viewModel.vehicle {
                    VStack(alignment: .leading, spacing: 10) {
                        reportInfoRow(title: "Vehicle", value: vehicle.name)
                        reportInfoRow(title: "Plate", value: vehicle.registrationNumber)
                        reportInfoRow(title: "Type", value: vehicle.vehicleType)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    Task {
                        await onGenerate()
                    }
                } label: {
                    HStack {
                        if viewModel.isGeneratingUsageReport {
                            ProgressView()
                                .tint(.white)
                            Text("Generating Report...")
                                .font(.headline)
                        } else {
                            Image(systemName: "doc.richtext")
                            Text("Generate PDF Report")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.isGeneratingUsageReport)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Usage Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func reportInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}
