import Foundation
import Combine
import Supabase
import UIKit

struct VehicleDocument: Identifiable, Hashable {
    let id: String
    let type: String
    var fileURL: String = ""
    var fileName: String? = nil

    var title: String {
        switch type.uppercased() {
        case "RC":
            return "RC"
        case "INSURANCE":
            return "Insurance"
        case "PUC":
            return "PUC"
        default:
            return type.capitalized
        }
    }

    var statusText: String {
        switch type.uppercased() {
        case "RC":
            return "Valid"
        case "INSURANCE":
            return "Expiring Soon"
        case "PUC":
            return "Expired"
        default:
            return "Available"
        }
    }
}

struct VehicleUsageReportResult {
    let localURL: URL
    let publicURL: String
    let fileName: String
}

private struct VehicleUpdatePayload: Encodable {
    let vehicle_name: String
    let number_plate: String
    let brand: String?
    let model: String?
    let image_url: String?
    let vehicle_type: String
    let fuel_type: String?
    let model_year: String?
    let vin: String?
    let registration_no: String?
    let registration_date: String?
    let rc_expiry_date: String?
    let puc_expiry_date: String?
    let is_sdvs_enabled: Bool
}

@MainActor
class VehicleDetailViewModel: ObservableObject {

    @Published var vehicle: Vehicle?
    @Published var documents: [VehicleDocument] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var documentsErrorMessage: String?
    @Published var maintenanceReports: [WorkOrderReportRecord] = []
    @Published var autofilledFields: Set<String> = []
    @Published var isGeneratingUsageReport = false
    @Published var isSdvsEnabled = false

    init(initialVehicle: Vehicle? = nil) {
        self.vehicle = initialVehicle
        self.isSdvsEnabled = initialVehicle?.isSdvsEnabled ?? false
    }



    func processVehicleOCR(from source: Any) async {
        let rawText = await VehicleOCRService.shared.recognizeText(from: source)
        print("OCR Raw Text: \(rawText)")

        let result = extractVehicleData(from: rawText)
        print("OCR Result: \(result)")

        await MainActor.run {
            guard var currentVehicle = self.vehicle else { return }
            self.autofilledFields.removeAll()

            if let plate = result.plate {
                currentVehicle.registrationNumber = plate
                self.autofilledFields.insert("licensePlate")
            }
            if let brand = result.manufacturer {
                currentVehicle.brand = brand
                let modelName = result.model ?? ""
                currentVehicle.model = modelName
                currentVehicle.name = "\(brand) \(modelName)".trimmingCharacters(in: .whitespaces)
                self.autofilledFields.insert("vehicleName")
                self.autofilledFields.insert("brand")
                self.autofilledFields.insert("model")
            }
            if let year = result.modelYear {
                currentVehicle.modelYear = year
                self.autofilledFields.insert("modelYear")
            }
            self.vehicle = currentVehicle
        }
    }

    private func extractVehicleData(from text: String) -> (plate: String?, vin: String?, manufacturer: String?, model: String?, modelYear: String?) {
        let raw = text.uppercased()
        let normalized = raw.replacingOccurrences(of: "O", with: "0").replacingOccurrences(of: "I", with: "1")
        let plateRegex = "[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}"
        let yearRegex = "\\b(19|20)\\d{2}\\b"

        let plate = normalized.range(of: plateRegex, options: .regularExpression).map { String(normalized[$0]) }
        let year = raw.range(of: yearRegex, options: .regularExpression).map { String(raw[$0]) }
        let brands = ["MARUTI", "HYUNDAI", "TATA", "HONDA", "TOYOTA", "MAHINDRA", "ASHOK LEYLAND", "KIA", "MG", "BMW", "MERCEDES", "AUDI", "JEEP", "SKODA", "VOLKSWAGEN", "FIAT", "RENAULT", "NISSAN", "MITSUBISHI", "FORD", "CHEVROLET"]
        let manufacturer = brands.first(where: { raw.contains($0) })
        let models = ["SWIFT", "DZIRE", "BALENO", "CRETA", "NEXON", "THAR", "I20", "VITARA", "BREZZA", "ERTIGA", "INNOVA", "FORTUNER", "ALTO", "WAGONR", "CELERIO", "DZIRE", "Tiago", "TIGOR", "PUNCH", "HARRIER", "SAFARI", "SCORPIO", "XUV700", "XUV300", "ALTROZ", "NEXON EV", "TIGOR EV", "ACTIVA", "DESTINI", "DIO", "NAVAGER"]
        let model = models.first(where: { raw.contains($0) })

        return (plate, nil, manufacturer, model, year)
    }
    func fetchVehicle(vehicleId: UUID) async {
        if self.vehicle == nil {
            isLoading = true
        }

        errorMessage = nil
        documentsErrorMessage = nil
        print("Opening vehicle detail id:", vehicleId.uuidString)

        do {
            let response = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("""
                    vehicle_id,
                    vehicle_name,
                    number_plate,
                    brand,
                    model,
                    image_url,
                    vehicle_type,
                    fuel_type,
                    model_year,
                    status,
                    vin,
                    registration_no,
                    registration_date,
                    rc_expiry_date,
                    puc_expiry_date
                """)
                .eq("vehicle_id", value: vehicleId.uuidString.lowercased())
                .single()
                .execute()

            print("Vehicle detail response:", String(data: response.data, encoding: .utf8) ?? "")
            self.vehicle = try Self.parseVehicle(from: response.data)

            do {
                let documentsData = try await fetchVehicleDocumentsData(vehicleId: vehicleId)
                print("Vehicle documents response:", String(data: documentsData, encoding: .utf8) ?? "")
                let fetchedDocuments = try Self.parseDocuments(from: documentsData)
                print("Vehicle documents count:", fetchedDocuments.count)
                self.documents = fetchedDocuments
                await fetchMaintenanceReports(vehicleId: vehicleId)
                self.documentsErrorMessage = nil
            } catch {
                print("Error fetching vehicle documents:", error)
                self.documents = []
                self.documentsErrorMessage = error.localizedDescription
            }
        } catch {
            print("Error fetching vehicle:", error)
            errorMessage = error.localizedDescription
            documents = []
        }

        isLoading = false
    }

    func updateVehicle() async -> Bool {
        guard let vehicle else { return false }

        do {
            errorMessage = nil
            let payload = VehicleUpdatePayload(
                vehicle_name: vehicle.name,
                number_plate: vehicle.registrationNumber,
                brand: vehicle.brand,
                model: vehicle.model,
                image_url: vehicle.imageURL,
                vehicle_type: vehicle.vehicleType,
                fuel_type: vehicle.fuelType,
                model_year: vehicle.modelYear,
                vin: vehicle.vin,
                registration_no: vehicle.rcNumber,
                registration_date: vehicle.registrationDate,
                rc_expiry_date: vehicle.rcExpiryDate,
                puc_expiry_date: vehicle.pucExpiryDate,
                is_sdvs_enabled: isSdvsEnabled
            )

            try await SupabaseManager.shared.client
                .from("vehicles")
                .update(payload)
                .eq("vehicle_id", value: vehicle.id.uuidString.lowercased())
                .execute()

            try await syncDocuments(for: vehicle.id)

            var components = URLComponents(string: "\(SUPABASE_URL)/rest/v1/vehicle_documents")!
            components.queryItems = [
                URLQueryItem(name: "select", value: "document_id,document_type,file_name,file_url,uploaded_at"),
                URLQueryItem(name: "vehicle_id", value: "eq.\(vehicle.id.uuidString.lowercased())")
            ]
            guard let url = components.url else { throw URLError(.badURL) }
            var request = URLRequest(url: url)
            request.addValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
            request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: request)
            documents = try Self.parseDocuments(from: data)
            return true
        } catch {
            print("Update failed:", error)
            errorMessage = error.localizedDescription
            return false
        }
    }

    func generateVehicleUsageReport() async throws -> VehicleUsageReportResult {
        guard let vehicle else {
            throw NSError(
                domain: "VehicleUsageReport",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Vehicle details are not loaded yet."]
            )
        }

        isGeneratingUsageReport = true
        defer { isGeneratingUsageReport = false }

        let trips = try await fetchUsageTrips(for: vehicle.id)
        let fuelLogs = try await fetchFuelLogs(for: vehicle.id)
        let localURL = try VehicleUsageReportGenerator.generate(vehicle: vehicle, trips: trips, fuelLogs: fuelLogs)
        let pdfData = try Data(contentsOf: localURL)
        let uploaded = try await uploadVehicleUsageReportToSupabase(
            pdfData: pdfData,
            vehicleId: vehicle.id,
            plate: vehicle.registrationNumber
        )
        try await saveVehicleUsageReportRecord(
            vehicleId: vehicle.id,
            reportUrl: uploaded.publicURL,
            reportName: uploaded.fileName,
            fileSize: pdfData.count
        )
        return VehicleUsageReportResult(
            localURL: localURL,
            publicURL: uploaded.publicURL,
            fileName: uploaded.fileName
        )
    }

    private func fetchUsageTrips(for vehicleId: UUID) async throws -> [VehicleUsageTrip] {
        try await SupabaseManager.shared.client
            .from("trips")
            .select("""
                trip_id,
                trip_name,
                origin,
                destination,
                status,
                pickup_time,
                start_time,
                end_time,
                distance_travelled,
                client_contact
            """)
            .eq("vehicle_id", value: vehicleId.uuidString.lowercased())
            .order("pickup_time", ascending: false)
            .execute()
            .value
    }

    private func fetchFuelLogs(for vehicleId: UUID) async throws -> [VehicleUsageReportFuelLog] {
        try await SupabaseManager.shared.client
            .from("fuel_logs")
            .select("""
                trip_id,
                fuel_volume,
                odometer_reading
            """)
            .eq("vehicle_id", value: vehicleId.uuidString.lowercased())
            .execute()
            .value
    }

    private func uploadVehicleUsageReportToSupabase(
        pdfData: Data,
        vehicleId: UUID,
        plate: String
    ) async throws -> (publicURL: String, fileName: String) {
        let sanitizedPlate = plate.replacingOccurrences(of: " ", with: "_")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "Vehicle_Usage_Report_\(sanitizedPlate)_\(timestamp).pdf"
        let path = "usage-reports/\(vehicleId.uuidString.lowercased())/\(fileName)"

        try await SupabaseManager.shared.client.storage
            .from("vehicle-documents")
            .upload(
                path,
                data: pdfData,
                options: FileOptions(contentType: "application/pdf")
            )

        let publicURL = try SupabaseManager.shared.client.storage
            .from("vehicle-documents")
            .getPublicURL(path: path)

        return (publicURL.absoluteString, fileName)
    }

    private func saveVehicleUsageReportRecord(
        vehicleId: UUID,
        reportUrl: String,
        reportName: String,
        fileSize: Int
    ) async throws {
        struct UsageReportRecord: Encodable {
            let vehicle_id: UUID
            let document_type: String
            let file_url: String
            let file_name: String
            let file_size: Int
        }

        let record = UsageReportRecord(
            vehicle_id: vehicleId,
            document_type: "USAGE_REPORT",
            file_url: reportUrl,
            file_name: reportName,
            file_size: fileSize
        )

        try await SupabaseManager.shared.client
            .from("vehicle_documents")
            .upsert(record, onConflict: "vehicle_id,document_type")
            .execute()
    }

    func uploadImage(image: UIImage, type: String = "VEHICLE") async {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }

        let fileName = UUID().uuidString + ".jpg"
        let bucket = type == "VEHICLE" ? "vehicle-images" : "vehicle-documents"

        do {
            let storage = SupabaseManager.shared.client.storage
            let uploaded = try await storage.from(bucket).upload(
                path: fileName,
                file: data,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg")
            )

            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/\(bucket)/\(fileName)"

            if type == "VEHICLE" {
                self.vehicle?.imageURL = publicURL
            } else {
                setDocumentURL(publicURL, for: type)
            }

        } catch {
            print("Upload error:", error)
        }
    }

    func uploadDocument(fileURL: URL, type: String) async {
        let originalName = fileURL.lastPathComponent
        do {
            let data = try Data(contentsOf: fileURL)
            let fileExtension = fileURL.pathExtension.isEmpty ? "pdf" : fileURL.pathExtension
            let uniqueName = "\(UUID().uuidString).\(fileExtension)"

            let storage = SupabaseManager.shared.client.storage
            let contentType = fileExtension == "pdf" ? "application/pdf" : "application/octet-stream"

            let uploaded = try await storage.from("vehicle-documents").upload(
                path: uniqueName,
                file: data,
                options: FileOptions(cacheControl: "3600", contentType: contentType)
            )

            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/vehicle-documents/\(uniqueName)"
            setDocumentURL(publicURL, for: type, fileName: originalName)
        } catch {
            print("Document upload failed for \(type):", error)
            errorMessage = error.localizedDescription
        }
    }

    func document(for type: String) -> VehicleDocument? {
        documents.first { $0.type.uppercased() == type.uppercased() }
    }

    func setDocumentURL(_ url: String, for type: String, fileName: String? = nil) {
        let normalizedType = type.uppercased()
        let resolvedFileName = fileName ?? URL(string: url)?.lastPathComponent

        if let index = documents.firstIndex(where: { $0.type.uppercased() == normalizedType }) {
            documents[index].fileURL = url
            documents[index].fileName = resolvedFileName
        } else {
            documents.append(VehicleDocument(
                id: normalizedType,
                type: normalizedType,
                fileURL: url,
                fileName: resolvedFileName
            ))
        }
        documents = Self.sortDocuments(documents)
    }

    func syncDocuments(for vehicleID: UUID) async throws {
        try await SupabaseManager.shared.client
            .from("vehicle_documents")
            .delete()
            .eq("vehicle_id", value: vehicleID.uuidString.lowercased())
            .execute()

        let records = documents
            .filter { !$0.fileURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map {
            [
                "vehicle_id": vehicleID.uuidString.lowercased(),
                "document_type": $0.type,
                "file_url": $0.fileURL
            ]
        }

        guard !records.isEmpty else { return }

        try await SupabaseManager.shared.client
            .from("vehicle_documents")
            .insert(records)
            .execute()
    }
}

extension VehicleDetailViewModel {
    func fetchVehicleDocumentsData(vehicleId: UUID) async throws -> Data {
        guard var components = URLComponents(string: "\(SUPABASE_URL)/rest/v1/vehicle_documents") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "select", value: "document_id,document_type,file_name,uploaded_at"),
            URLQueryItem(name: "vehicle_id", value: "eq.\(vehicleId.uuidString.lowercased())")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.addValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Failed to fetch vehicle documents"
            throw NSError(
                domain: "VehicleDetail",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        return data
    }

    func fetchDocumentURL(for type: String, vehicleId: UUID) async -> String? {
        do {
            let response = try await SupabaseManager.shared.client
                .from("vehicle_documents")
                .select("file_url")
                .eq("vehicle_id", value: vehicleId.uuidString.lowercased())
                .eq("document_type", value: type.uppercased())
                .limit(1)
                .execute()

            let rows = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] ?? []
            guard let row = rows.first,
                  let fileUrl = row["file_url"] as? String else {
                return nil
            }
            return fileUrl
        } catch {
            print("Error fetching document URL: \(error)")
            return nil
        }
    }

    static func parseVehicleDetail(from data: Data) throws -> (vehicle: Vehicle, documents: [VehicleDocument]) {
        guard let row = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "VehicleDetail",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Vehicle response was not a JSON object."]
            )
        }

        let vehicleData = try JSONSerialization.data(withJSONObject: row)
        let vehicle = try parseVehicle(from: vehicleData)

        let nestedDocuments = row["vehicle_documents"] ?? []
        let documentData = try JSONSerialization.data(withJSONObject: nestedDocuments)
        let documents = try parseDocuments(from: documentData)
        return (vehicle, documents)
    }

    static func parseVehicle(from data: Data) throws -> Vehicle {
        guard let row = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "VehicleDetail",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Vehicle response was not a JSON object."]
            )
        }

        guard let idString = stringValue(row["vehicle_id"]),
              let id = UUID(uuidString: idString) else {
            throw NSError(
                domain: "VehicleDetail",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Vehicle record is missing a valid id."]
            )
        }

        let plate = stringValue(row["number_plate"])
        let name = stringValue(row["vehicle_name"])
        let type = stringValue(row["vehicle_type"])

        var vehicle = Vehicle(
            id: id,
            name: preferredText(name, fallback: plate, defaultValue: "Unnamed Vehicle"),
            registrationNumber: preferredText(plate, fallback: nil, defaultValue: "No Plate"),
            brand: stringValue(row["brand"]),
            model: stringValue(row["model"]),
            imageURL: stringValue(row["image_url"]),
            vehicleType: preferredText(type, fallback: nil, defaultValue: "Unknown"),
            fuelType: stringValue(row["fuel_type"]),
            modelYear: stringValue(row["model_year"])
        )
        vehicle.vin = stringValue(row["vin"]) ?? ""
        vehicle.rcNumber = stringValue(row["registration_no"]) ?? ""
        vehicle.registrationDate = stringValue(row["registration_date"]) ?? ""
        vehicle.rcExpiryDate = stringValue(row["rc_expiry_date"]) ?? ""
        vehicle.pucExpiryDate = stringValue(row["puc_expiry_date"]) ?? ""
        return vehicle
    }

    static func parseDocuments(from data: Data) throws -> [VehicleDocument] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let parsed: [VehicleDocument] = rows.compactMap { row in
            guard let type = stringValue(row["document_type"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !type.isEmpty else {
                return nil
            }

            let fileURL = stringValue(row["file_url"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return VehicleDocument(
                id: type.uppercased(),
                type: type.uppercased(),
                fileURL: fileURL,
                fileName: row["file_name"] as? String ?? stringValue(row["document_type"])
            )
        }

        return sortDocuments(parsed)
    }

    static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case is NSNull, nil:
            return nil
        default:
            return String(describing: value!)
        }
    }

    static func preferredText(_ primary: String?, fallback: String?, defaultValue: String) -> String {
        let primaryTrimmed = primary?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let primaryTrimmed, !primaryTrimmed.isEmpty {
            return primaryTrimmed
        }

        let fallbackTrimmed = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fallbackTrimmed, !fallbackTrimmed.isEmpty {
            return fallbackTrimmed
        }

        return defaultValue
    }

    static func sortDocuments(_ documents: [VehicleDocument]) -> [VehicleDocument] {
        let ordering = ["RC": 0, "INSURANCE": 1, "PUC": 2]
        return documents.sorted { lhs, rhs in
            let lhsOrder = ordering[lhs.type.uppercased()] ?? 99
            let rhsOrder = ordering[rhs.type.uppercased()] ?? 99
            if lhsOrder == rhsOrder {
                return lhs.title < rhs.title
            }
            return lhsOrder < rhsOrder
        }
    }

    func fetchMaintenanceReports(vehicleId: UUID) async {
        do {
            struct WOId: Decodable { let work_order_id: UUID }

            let woResponse = try await SupabaseManager.shared.client
                .from("work_orders")
                .select("work_order_id")
                .eq("vehicle_id", value: vehicleId.uuidString.lowercased())
                .execute()

            let woIds = try JSONDecoder().decode([WOId].self, from: woResponse.data).map { $0.work_order_id.uuidString }

            guard !woIds.isEmpty else {
                await MainActor.run { self.maintenanceReports = [] }
                return
            }

            let reportsResponse = try await SupabaseManager.shared.client
                .from("work_order_reports")
                .select()
                .in("work_order_id", values: woIds)
                .execute()

            let reports = try JSONDecoder().decode([WorkOrderReportRecord].self, from: reportsResponse.data)

            await MainActor.run {
                self.maintenanceReports = reports
            }
        } catch {
            print("🚨 Error fetching maintenance reports: \(error)")
        }
    }
}
