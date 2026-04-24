import SwiftUI
import Supabase

@MainActor
final class DocumentVaultViewModel: ObservableObject {
    @Published var documents: [VehicleDocument] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let client = SupabaseManager.shared.client
    
    func fetchDocuments(for vehicleId: UUID? = nil, driverId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            var query = client.from("vehicle_documents").select()
            
            if let vId = vehicleId {
                query = query.eq("vehicle_id", value: vId.uuidString)
            } else if let dId = driverId {
                query = query.eq("driver_id", value: dId.uuidString)
            }
            
            let fetched: [VehicleDocument] = try await query
                .order("expiry_date", ascending: true)
                .execute()
                .value
            
            self.documents = fetched
            
            // Check for soon-to-expire documents and trigger alerts if needed
            checkForRedAlerts(in: fetched)
            
        } catch {
            print("🚨 Failed to fetch documents: \(error)")
            errorMessage = "Could not load documents."
        }
        
        isLoading = false
    }
    
    private func checkForRedAlerts(in docs: [VehicleDocument]) {
        let expiringSoon = docs.filter { $0.isExpiringSoon }
        for doc in expiringSoon {
            Task {
                await triggerRedAlert(for: doc)
            }
        }
    }
    
    private func triggerRedAlert(for doc: VehicleDocument) async {
        do {
            let session = try? await client.auth.session
            let currentUserId = session?.user.id
            
            let alertData: [String: AnyEncodable] = [
                "recipient_id": AnyEncodable(currentUserId?.uuidString ?? ""), // Managers receive alerts
                "type": AnyEncodable("Document"),
                "title": AnyEncodable("RED ALERT: \(doc.type.rawValue) Expiring"),
                "message": AnyEncodable("The \(doc.type.rawValue) for this fleet entity expires in \(doc.daysToExpiry) days (\(formattedDate(doc.expiryDate))). Please renew immediately."),
                "related_entity_id": AnyEncodable(doc.id),
                "is_read": AnyEncodable(false),
                "sender_id": AnyEncodable(currentUserId?.uuidString ?? "")
            ]
            
            try await client.from("notifications").insert(alertData).execute()
            print("🚀 Red Alert triggered for \(doc.type.rawValue)")
            
        } catch {
            print("🚨 Failed to trigger red alert: \(error)")
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// Reuse AnyEncodable if needed or define locally if not globally available
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}


struct DocumentVaultView: View {
    @StateObject private var vm = DocumentVaultViewModel()
    let vehicleId: UUID?
    let driverId: UUID?
    
    init(vehicleId: UUID? = nil, driverId: UUID? = nil) {
        self.vehicleId = vehicleId
        self.driverId = driverId
    }
    
    var body: some View {
        List {
            if vm.documents.isEmpty && !vm.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No documents found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                Section("Active Documents") {
                    ForEach(vm.documents) { doc in
                        DocumentRow(doc: doc)
                    }
                }
            }
        }
        .navigationTitle("Document Vault")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Upload document logic
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await vm.fetchDocuments(for: vehicleId, driverId: driverId)
        }
    }
}

struct DocumentRow: View {
    let doc: VehicleDocument
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(doc.isExpired ? Color.red.opacity(0.1) : (doc.isExpiringSoon ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1)))
                    .frame(width: 44, height: 44)
                
                Image(systemName: doc.type.icon)
                    .foregroundColor(doc.isExpired ? .red : (doc.isExpiringSoon ? .orange : .blue))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.type.rawValue)
                    .font(.headline)
                
                if let num = doc.documentNumber {
                    Text(num)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Expires")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(formattedDate(doc.expiryDate))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(doc.isExpired ? .red : (doc.isExpiringSoon ? .orange : .primary))
                
                if doc.isExpiringSoon {
                    Text("\(doc.daysToExpiry) days left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                } else if doc.isExpired {
                    Text("EXPIRED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
