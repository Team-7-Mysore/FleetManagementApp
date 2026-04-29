import SwiftUI
import Combine
import UIKit
import Supabase
import Foundation

struct VehicleSavePayload: Encodable {
    var imageUrl: String
    var vehicleName: String
    var registrationNumber: String
    var vin: String
    var brand: String
    var manufacturer: String
    var model: String
    var modelYear: Int
    var vehicleType: String
    var fuelType: String
    var registrationDate: String
    var pucExpiry: String
    var rcExpiry: String
    var imageRCNumber: String?
    var documents: [VehicleDocumentPayload]

    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
        case vehicleName
        case registrationNumber
        case vin, brand, manufacturer, model
        case modelYear = "model_year"
        case vehicleType
        case fuelType
        case registrationDate
        case pucExpiry
        case rcExpiry
        case imageRCNumber = "rc_number"
        case documents
    }
}

struct VehicleDocumentPayload: Encodable {
    var type: String
    var url: String
    var name: String
    var size: Int?

    enum CodingKeys: String, CodingKey {
        case type, url, name, size
    }
}

private struct VehicleSaveResponse: Decodable {
    let vehicleId: UUID
    let success: Bool?

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case success
    }
}

private struct EdgeFunctionErrorResponse: Decodable {
    let error: String
}

private struct DirectVehicleInsertPayload: Encodable {
    var imageUrl: String
    var vehicleName: String
    var numberPlate: String
    var vin: String
    var brand: String
    var manufacturer: String
    var model: String
    var modelYear: Int
    var vehicleType: String
    var fuelType: String
    var registrationDate: String
    var pucExpiryDate: String
    var rcExpiryDate: String
    var hasRC: Bool
    var hasInsurance: Bool
    var hasPUC: Bool

    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
        case vehicleName = "vehicle_name"
        case numberPlate = "number_plate"
        case vin, brand, manufacturer, model
        case modelYear = "model_year"
        case vehicleType = "vehicle_type"
        case fuelType = "fuel_type"
        case registrationDate = "registration_date"
        case pucExpiryDate = "puc_expiry_date"
        case rcExpiryDate = "rc_expiry_date"
        case hasRC = "has_rc"
        case hasInsurance = "has_insurance"
        case hasPUC = "has_puc"
    }
}

private struct DirectVehicleInsertResult: Decodable {
    let vehicleId: UUID

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
    }
}

private struct VehicleDocumentInsertPayload: Encodable {
    let vehicleId: String
    let documentType: String
    let fileUrl: String
    let fileName: String
    let fileSize: Int?

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case documentType = "document_type"
        case fileUrl = "file_url"
        case fileName = "file_name"
        case fileSize = "file_size"
    }
}

class AddVehicleViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSuccess = false
    @Published var autofilledFields: Set<String> = []
    // MARK: - Form Fields
    @Published var vehicleName = ""
    @Published var licensePlate = ""
    @Published var vin = ""
    @Published var brand = ""
    @Published var manufacturer = ""
    @Published var model = ""
    @Published var modelYear = ""
    @Published var vehicleType = "Truck"
    @Published var fuelType = "Diesel"
    @Published var isAutoFilled = false
    // MARK: - Dates
    @Published var registrationDate = Date()
    @Published var pucExpiry = Date()
    @Published var rcExpiry = Date()

    // Asset URLs
    @Published var vehicleImageURL: String?
    @Published var rcURL: String?
    @Published var insuranceURL: String?
    @Published var pucURL: String?

    @Published var localVehicleImage: UIImage?
    @Published var rcFileName: String?
    @Published var insuranceFileName: String?
    @Published var pucFileName: String?

    // MARK: - Validation Checkers

    var isPlateValidCheck: Bool {
        isValidPlate(licensePlate)
    }

    var isFormValid: Bool {
        let isNameValid = !vehicleName.trimmingCharacters(in: .whitespaces).isEmpty
        let isVinValid = vin.count == 17
        let isPlateValid = isPlateValidCheck

        return isNameValid && isVinValid && isPlateValid && !isLoading
    }

    // MARK: - Formatting Helpers

    func formatPlate(_ input: String) -> String {
        let raw = input.uppercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
        let normalized = String(raw.prefix(10))

        var result = ""
        for (index, char) in normalized.enumerated() {
            if index == 2 || index == 4 || index == 6 {
                result.append("-")
            }
            result.append(char)
        }
        return result
    }

    private func isValidPlate(_ input: String) -> Bool {
        // Pattern: AA-00-AA-0000
        let regex = "^[A-Z]{2}-[0-9]{2}-[A-Z]{1,2}-[0-9]{4}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: input)
    }

    private func isValidRC(_ input: String) -> Bool {
        let rcRegex = "^[A-Z0-9/]{8,20}$"
        return NSPredicate(format: "SELF MATCHES %@", rcRegex).evaluate(with: input.uppercased())
    }

    // MARK: - Persistence (Save to Supabase)
    func decodeVIN(_ vin: String) -> (manufacturer: String?, brand: String?) {

        let wmi = String(vin.prefix(3))

        let map: [String: (String, String)] = [
            "MA3": ("Maruti Suzuki", "Maruti"),
            "MBH": ("Hyundai", "Hyundai"),
            "MAT": ("Tata Motors", "Tata"),
            "ME4": ("Honda", "Honda"),
            "MHF": ("Toyota", "Toyota"),
            "MA1": ("Mahindra", "Mahindra")
        ]

        return map[wmi] ?? (nil, nil)
    }
    func parseDates(_ dates: [String]) -> (registration: Date?, expiry: Date?) {

        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"

        let parsed = dates.compactMap {
            formatter.date(from: $0.replacingOccurrences(of: "-", with: "/"))
        }.sorted()

        return (
            registration: parsed.first,
            expiry: parsed.last
        )
    }
    func processVehicleOCR(from source: Any) async {
        let rawText = await VehicleOCRService.shared.recognizeText(from: source)
        let result = extractVehicleData(from: rawText)

        await MainActor.run {
            self.autofilledFields.removeAll()

            // 1. Handle Model & Brand
            if let modelFound = result.model {
                self.model = modelFound
                self.autofilledFields.insert("model")
            }
            
            if let brandFound = result.manufacturer {
                self.brand = brandFound
                self.manufacturer = brandFound
                self.autofilledFields.insert("brand")
                self.autofilledFields.insert("manufacturer")
            }
            if let yearFound = result.modelYear {
                        self.modelYear = yearFound
                        self.autofilledFields.insert("modelYear") // Track for autofill
                    }

            // 2. Generate Vehicle Name (e.g., "MARUTI SWIFT")
            let brandName = self.brand.isEmpty ? "" : self.brand
            let modelName = self.model.isEmpty ? "" : self.model
            let generatedName = "\(brandName) \(modelName)".trimmingCharacters(in: .whitespaces)
            let resolvedVehicleName = result.vehicleName ?? (generatedName.isEmpty ? nil : generatedName)

            if let resolvedVehicleName, !resolvedVehicleName.isEmpty {
                self.vehicleName = resolvedVehicleName
                self.autofilledFields.insert("vehicleName")
            }

            // 3. Handle Plate
            if let plate = result.plate {
                self.licensePlate = self.formatPlate(plate)
                self.autofilledFields.insert("licensePlate")
            }

            if let vehicleTypeFound = result.vehicleType {
                self.vehicleType = vehicleTypeFound
                self.autofilledFields.insert("vehicleType")
            }

            // 4. Handle VIN
            if let vinFound = result.vin {
                self.vin = vinFound
                self.autofilledFields.insert("vin")
            }

            // 5. Handle Dates
            let parsed = parseDates(result.dates)
            if let reg = parsed.registration {
                self.registrationDate = reg
                self.autofilledFields.insert("registrationDate")
            }
            if let exp = parsed.expiry {
                self.rcExpiry = exp
                self.autofilledFields.insert("rcExpiry")
            }

            self.isAutoFilled = true
        }
    }
    func saveVehicle() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        let sqlDateFormatter = DateFormatter()
        sqlDateFormatter.dateFormat = "yyyy-MM-dd"

        do {
            let documentPayloads = [
                rcURL.map {
                    VehicleDocumentPayload(
                        type: "RC",
                        url: $0,
                        name: rcFileName ?? "RC_Doc",
                        size: nil
                    )
                },
                insuranceURL.map {
                    VehicleDocumentPayload(
                        type: "INSURANCE",
                        url: $0,
                        name: insuranceFileName ?? "Insurance_Doc",
                        size: nil
                    )
                },
                pucURL.map {
                    VehicleDocumentPayload(
                        type: "PUC",
                        url: $0,
                        name: pucFileName ?? "PUC_Doc",
                        size: nil
                    )
                }
            ].compactMap { $0 }

            let payload = VehicleSavePayload(
                imageUrl: vehicleImageURL ?? "",
                vehicleName: vehicleName.trimmingCharacters(in: .whitespaces),
                registrationNumber: licensePlate.trimmingCharacters(in: .whitespacesAndNewlines),
                vin: vin.uppercased().trimmingCharacters(in: .whitespaces),
                brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                modelYear: Int(modelYear) ?? 0,
                vehicleType: vehicleType,
                fuelType: fuelType,
                registrationDate: sqlDateFormatter.string(from: registrationDate),
                pucExpiry: sqlDateFormatter.string(from: pucExpiry),
                rcExpiry: sqlDateFormatter.string(from: rcExpiry),
                imageRCNumber: nil,
                documents: documentPayloads
            )

            let directPayload = DirectVehicleInsertPayload(
                imageUrl: payload.imageUrl,
                vehicleName: payload.vehicleName,
                numberPlate: payload.registrationNumber,
                vin: payload.vin,
                brand: payload.brand,
                manufacturer: payload.manufacturer,
                model: payload.model,
                modelYear: payload.modelYear,
                vehicleType: payload.vehicleType,
                fuelType: payload.fuelType,
                registrationDate: payload.registrationDate,
                pucExpiryDate: payload.pucExpiry,
                rcExpiryDate: payload.rcExpiry,
                hasRC: documentPayloads.contains(where: { $0.type == "RC" }),
                hasInsurance: documentPayloads.contains(where: { $0.type == "INSURANCE" }),
                hasPUC: documentPayloads.contains(where: { $0.type == "PUC" })
            )

            guard let functionURL = URL(string: "\(SupabaseConfig.url.absoluteString)/functions/v1/bright-action") else {
                throw NSError(domain: "SaveError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid function URL"])
            }

            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(payload)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "SaveError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
            }

            if httpResponse.statusCode == 404 {
                try await saveVehicleDirectly(vehiclePayload: directPayload, documentPayloads: documentPayloads)
                await MainActor.run { self.isSuccess = true }
                await MainActor.run { self.isLoading = false }
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let message = (try? JSONDecoder().decode(EdgeFunctionErrorResponse.self, from: data).error)
                    ?? String(data: data, encoding: .utf8)
                    ?? "Failed to save vehicle"
                throw NSError(domain: "SaveError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }

            _ = try JSONDecoder().decode(VehicleSaveResponse.self, from: data)

            await MainActor.run { self.isSuccess = true }
        } catch {
            print("Save error: \(error)")
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }

        await MainActor.run { self.isLoading = false }
    }

    private func saveVehicleDirectly(
        vehiclePayload: DirectVehicleInsertPayload,
        documentPayloads: [VehicleDocumentPayload]
    ) async throws {
        let insertedVehicle: DirectVehicleInsertResult = try await SupabaseManager.shared.client
            .from("vehicles")
            .upsert(vehiclePayload, onConflict: "number_plate")
            .select("vehicle_id")
            .single()
            .execute()
            .value

        let vehicleId = insertedVehicle.vehicleId.uuidString.lowercased()
        let normalizedTypes = documentPayloads.map { $0.type.uppercased() }

        if !normalizedTypes.isEmpty {
            try await SupabaseManager.shared.client
                .from("vehicle_documents")
                .delete()
                .eq("vehicle_id", value: vehicleId)
                .in("document_type", values: normalizedTypes)
                .execute()
        }

        let documentRecords = documentPayloads.map {
            VehicleDocumentInsertPayload(
                vehicleId: vehicleId,
                documentType: $0.type.uppercased(),
                fileUrl: $0.url,
                fileName: $0.name,
                fileSize: $0.size
            )
        }

        if !documentRecords.isEmpty {
            try await SupabaseManager.shared.client
                .from("vehicle_documents")
                .insert(documentRecords)
                .execute()
        }
    }

    // MARK: - Upload Methods
    func uploadImage(image: UIImage, type: String) async {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let fileName = "\(UUID().uuidString).jpg"
        let bucket = (type == "VEHICLE") ? "vehicle-images" : "vehicle-documents"
        do {
            let storage = SupabaseManager.shared.client.storage.from(bucket)
            try await storage.upload(path: fileName, file: data, options: FileOptions(contentType: "image/jpeg"))
            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/\(bucket)/\(fileName)"
            await MainActor.run {
                if type == "VEHICLE" { self.vehicleImageURL = publicURL }
                else if type == "RC" { self.rcURL = publicURL; self.rcFileName = "Photo_RC.jpg" }
            }
        } catch { print("Upload failed") }
    }
    func extractVehicleData(from text: String) -> (
        plate: String?,
        vin: String?,
        dates: [String],
        vehicleName: String?,
        manufacturer: String?,
        model: String?,
        modelYear: String?,
        vehicleType: String?
    ) {
        let rawCleaned = text.uppercased()
        
        // Normalize ONLY for Plate/VIN (turning letters that look like numbers into numbers)
        let normalizedForRegex = rawCleaned
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1")

        // MARK: - Regex Definitions
        let plateRegex = "[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}"
        let vinRegex = "[A-HJ-NPR-Z0-9]{17}"
        let dateRegex = "\\b\\d{2}[-/]\\d{2}[-/]\\d{4}\\b"
        let yearRegex = "\\b(19|20)\\d{2}\\b"

        // MARK: - Regex Extraction
        // Note: Added .regularExpression to fix the contextual base error
        let plateRange = normalizedForRegex.range(of: plateRegex, options: .regularExpression)
        let vinRange = normalizedForRegex.range(of: vinRegex, options: .regularExpression)

        let plate = extractPlate(from: rawCleaned)
            ?? (plateRange != nil ? String(normalizedForRegex[plateRange!]) : nil)
        let vin = vinRange != nil ? String(normalizedForRegex[vinRange!]) : nil
        let dates = rawCleaned.matches(for: dateRegex)

        let labeledVehicleName = labeledValue(in: rawCleaned, for: [
            "VEHICLE NAME",
            "MODEL NAME"
        ])
        let labeledManufacturer = labeledValue(in: rawCleaned, for: [
            "MANUFACTURER",
            "MAKE",
            "BRAND"
        ])

        // MARK: - Keyword Matching
        let brands = [
            "ROYAL ENFIELD", "BAJAJ", "TVS", "HERO", "YAMAHA", "KTM", "OLA",
            "ATHER", "HONDA", "SUZUKI", "MARUTI", "HYUNDAI", "TATA", "TOYOTA",
            "MAHINDRA", "KIA", "MG", "SKODA", "VOLKSWAGEN", "VW", "RENAULT"
        ]
        let manufacturer = labeledManufacturer
            ?? brands.first(where: { rawCleaned.contains($0) })
            ?? manufacturerFromVehicleName(labeledVehicleName, knownBrands: brands)

        let models = [
            "CLASSIC 350", "CLASSIC 650", "BULLET 350", "HUNTER 350", "METEOR 350",
            "THUNDERBIRD", "INTERCEPTOR 650", "CONTINENTAL GT", "HIMALAYAN",
            "PULSAR", "DOMINAR", "APACHE", "SPLENDOR", "SHINE", "UNICORN", "ACTIVA",
            "ACCESS", "NTORQ", "JUPITER", "R15", "MT 15", "DUKE", "AETHER", "ATHER RIZTA",
            "SWIFT", "DZIRE", "BALENO", "VITARA", "BREZZA", "ALTO", "WAGONR", "CELERIO", "IGNIS",
            "I10", "I20", "CRETA", "VENUE", "VERNA", "TUCSON", "ALCAZAR",
            "NEXON", "PUNCH", "ALTROZ", "HARRIER", "SAFARI", "TIAGO", "TIGOR",
            "CITY", "AMAZE", "WRV", "JAZZ",
            "INNOVA", "FORTUNER", "HYRYDER", "GLANZA", "CAMRY",
            "SCORPIO", "XUV", "THAR", "BOLERO", "MARAZZO"
        ]
        let sanitizedVehicleName = sanitizedVehicleName(from: labeledVehicleName)
        let model = modelFromVehicleName(sanitizedVehicleName, manufacturer: manufacturer)
            ?? models.first(where: { rawCleaned.contains($0) })

        let vehicleType = inferVehicleType(from: rawCleaned)

        // MARK: - Model Year Extraction
        let yearRange = rawCleaned.range(of: yearRegex, options: .regularExpression)
        let modelYear = yearRange != nil ? String(rawCleaned[yearRange!]) : nil

        return (
            plate: plate,
            vin: vin,
            dates: dates,
            vehicleName: sanitizedVehicleName,
            manufacturer: manufacturer,
            model: model,
            modelYear: modelYear,
            vehicleType: vehicleType
        )
    }

    private func labeledValue(in text: String, for labels: [String]) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for (index, line) in lines.enumerated() {
            for label in labels {
                if line.hasPrefix(label + ":") {
                    let value = line.dropFirst(label.count + 1).trimmingCharacters(in: .whitespaces)
                    if let cleaned = cleanedLabeledValue(value), !cleaned.isEmpty { return cleaned }
                    if let nextLine = nextUsefulLine(after: index, in: lines) {
                        return nextLine
                    }
                }

                if line.hasPrefix(label + " ") {
                    let value = line.dropFirst(label.count + 1).trimmingCharacters(in: .whitespaces)
                    if let cleaned = cleanedLabeledValue(value), !cleaned.isEmpty { return cleaned }
                    if let nextLine = nextUsefulLine(after: index, in: lines) {
                        return nextLine
                    }
                }

                if line == label, let nextLine = nextUsefulLine(after: index, in: lines) {
                    return nextLine
                }
            }
        }

        return nil
    }

    private func manufacturerFromVehicleName(_ vehicleName: String?, knownBrands: [String]) -> String? {
        guard let vehicleName else { return nil }
        return knownBrands.first(where: { vehicleName.hasPrefix($0) })
    }

    private func modelFromVehicleName(_ vehicleName: String?, manufacturer: String?) -> String? {
        guard let vehicleName, !vehicleName.isEmpty else { return nil }
        guard let manufacturer, !manufacturer.isEmpty else { return vehicleName }

        let trimmed = vehicleName
            .replacingOccurrences(of: manufacturer, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmed.isEmpty ? nil : trimmed
    }

    private func sanitizedVehicleName(from value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.lowercased().hasSuffix(".pdf"),
              !trimmed.lowercased().hasSuffix(".jpg"),
              !trimmed.lowercased().hasSuffix(".jpeg"),
              !trimmed.lowercased().hasSuffix(".png"),
              !trimmed.contains("_") else { return nil }
        let bannedTerms = ["CERTIFICATE", "SUMMARY", "REPORT", "PROJECT:", "DOCUMENT", "REGISTRATION"]
        guard !bannedTerms.contains(where: { trimmed.contains($0) }) else { return nil }
        return trimmed
    }

    private func cleanedLabeledValue<S: StringProtocol>(_ value: S) -> String? {
        let trimmed = String(value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return looksLikeNoise(trimmed) ? nil : trimmed
    }

    private func nextUsefulLine(after index: Int, in lines: [String]) -> String? {
        guard index + 1 < lines.count else { return nil }
        for nextIndex in (index + 1)..<lines.count {
            let nextLine = lines[nextIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if nextLine.isEmpty || looksLikeNoise(nextLine) {
                continue
            }
            return nextLine
        }
        return nil
    }

    private func looksLikeNoise(_ text: String) -> Bool {
        let uppercased = text.uppercased()
        if uppercased.hasSuffix(".PDF") || uppercased.hasSuffix(".JPG") || uppercased.hasSuffix(".JPEG") || uppercased.hasSuffix(".PNG") {
            return true
        }
        if uppercased.contains("_") {
            return true
        }
        let bannedTerms = ["CERTIFICATE", "SUMMARY", "REPORT", "PROJECT:", "DOCUMENT", "REGISTRATION"]
        return bannedTerms.contains(where: { uppercased == $0 || uppercased.hasPrefix($0 + " ") })
    }

    private func plateFromLabeledValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1")
        let regex = try? NSRegularExpression(pattern: "[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}")
        let range = NSRange(location: 0, length: normalized.utf16.count)
        guard let match = regex?.firstMatch(in: normalized, range: range),
              let swiftRange = Range(match.range, in: normalized) else { return nil }
        return String(normalized[swiftRange])
    }

    private func extractPlate(from text: String) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let plateLabels = [
            "LICENSE PLATE",
            "REGISTRATION PLATE",
            "NUMBER PLATE",
            "REGISTRATION NUMBER",
            "REGISTRATION MARK",
            "REGN NO",
            "REGN. NO",
            "REGD NO",
            "REGD. NO"
        ]

        for (index, line) in lines.enumerated() {
            let upperLine = line.uppercased()
            guard plateLabels.contains(where: { upperLine.contains($0) }) else { continue }

            if let plate = plateFromLabeledValue(line) {
                return plate
            }

            if index + 1 < lines.count, let plate = plateFromLabeledValue(lines[index + 1]) {
                return plate
            }
        }

        return nil
    }

    private func inferVehicleType(from text: String) -> String? {
        if text.contains("TWO-WHEELER") || text.contains("MOTORCYCLE") || text.contains("BIKE") || text.contains("SCOOTER") {
            return "Bike"
        }
        if text.contains("BUS") {
            return "Bus"
        }
        if text.contains("TRUCK") || text.contains("LORRY") || text.contains("GOODS CARRIER") {
            return "Truck"
        }
        if text.contains("CAR") || text.contains("HATCHBACK") || text.contains("SEDAN") || text.contains("SUV") {
            return "Car"
        }
        return nil
    }

    func uploadFile(fileURL: URL, type: String) async {
        do {
            let data = try Data(contentsOf: fileURL)
            let fileName = "\(UUID().uuidString).\(fileURL.pathExtension)"
            let storage = SupabaseManager.shared.client.storage.from("vehicle-documents")
            try await storage.upload(path: fileName, file: data)
            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/vehicle-documents/\(fileName)"
            await MainActor.run {
                if type == "RC" {
                    self.rcURL = publicURL
                    self.rcFileName = fileURL.lastPathComponent
                } else if type == "INSURANCE" {
                    self.insuranceURL = publicURL
                    self.insuranceFileName = fileURL.lastPathComponent
                } else if type == "PUC" {
                    self.pucURL = publicURL
                    self.pucFileName = fileURL.lastPathComponent
                }
            }
        } catch { print("File failed") }
    }
}
extension String {
    func matches(for regex: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: regex)
        let results = regex?.matches(in: self, range: NSRange(startIndex..., in: self)) ?? []
        return results.map {
            String(self[Range($0.range, in: self)!])
        }
    }
}
