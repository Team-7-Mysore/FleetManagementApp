import SwiftUI
import Combine
import UIKit
import Supabase
import Foundation

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
        let documentsValid = rcURL != nil && insuranceURL != nil

        return isNameValid && isVinValid && isPlateValid  && documentsValid && !isLoading
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
    func processVehicleOCR(from image: UIImage) async {
        let rawText = await VehicleOCRService.shared.recognizeText(from: image)
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
            
            if !generatedName.isEmpty {
                self.vehicleName = generatedName
                self.autofilledFields.insert("vehicleName")
            }

            // 3. Handle Plate
            if let plate = result.plate {
                self.licensePlate = self.formatPlate(plate)
                self.autofilledFields.insert("licensePlate")
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

        let payload: [String: Any] = [
            "image_url": vehicleImageURL ?? "",
            "vehicleName": vehicleName.trimmingCharacters(in: .whitespaces),
            "registrationNumber": licensePlate,
            "vin": vin.uppercased().trimmingCharacters(in: .whitespaces),
            "brand": brand,
            "manufacturer": manufacturer,
            "model": model,
            "model_year": Int(modelYear) ?? 0,
            "vehicleType": vehicleType,
            "fuelType": fuelType,
            "registrationDate": sqlDateFormatter.string(from: registrationDate),
            "pucExpiry": sqlDateFormatter.string(from: pucExpiry),
            "rcExpiry": sqlDateFormatter.string(from: rcExpiry),
            "documents": [
                rcURL != nil ? ["type": "RC", "url": rcURL!, "name": rcFileName ?? "RC_Doc"] : nil,
                insuranceURL != nil ? ["type": "INSURANCE", "url": insuranceURL!, "name": insuranceFileName ?? "Insurance_Doc"] : nil,
                pucURL != nil ? ["type": "PUC", "url": pucURL!, "name": pucFileName ?? "PUC_Doc"] : nil
            ].compactMap { $0 }
        ]

        do {
            let functionURL = URL(string: "\(SUPABASE_URL)/functions/v1/bright-action")!
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                await MainActor.run { self.isSuccess = true }
            } else {
                throw NSError(domain: "SupabaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to save vehicle"])
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { self.isLoading = false }
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
        manufacturer: String?,
        model: String?,
        modelYear: String?
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

        let plate = plateRange != nil ? String(normalizedForRegex[plateRange!]) : nil
        let vin = vinRange != nil ? String(normalizedForRegex[vinRange!]) : nil
        let dates = rawCleaned.matches(for: dateRegex)

        // MARK: - Keyword Matching
        let brands = ["MARUTI", "HYUNDAI", "TATA", "HONDA", "TOYOTA", "MAHINDRA", "SUZUKI", "KIA", "MG", "SKODA", "VW", "RENAULT"]
        let manufacturer = brands.first(where: { rawCleaned.contains($0) })

        let models = [
            "SWIFT", "DZIRE", "BALENO", "VITARA", "BREZZA", "ALTO", "WAGONR", "CELERIO", "IGNIS",
            "I10", "I20", "CRETA", "VENUE", "VERNA", "TUCSON", "ALCAZAR",
            "NEXON", "PUNCH", "ALTROZ", "HARRIER", "SAFARI", "TIAGO", "TIGOR",
            "CITY", "AMAZE", "WRV", "JAZZ",
            "INNOVA", "FORTUNER", "HYRYDER", "GLANZA", "CAMRY",
            "SCORPIO", "XUV", "THAR", "BOLERO", "MARAZZO"
        ]
        let model = models.first(where: { rawCleaned.contains($0) })

        // MARK: - Model Year Extraction
        let yearRange = rawCleaned.range(of: yearRegex, options: .regularExpression)
        let modelYear = yearRange != nil ? String(rawCleaned[yearRange!]) : nil

        return (
            plate: plate,
            vin: vin,
            dates: dates,
            manufacturer: manufacturer,
            model: model,
            modelYear: modelYear
        )
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
