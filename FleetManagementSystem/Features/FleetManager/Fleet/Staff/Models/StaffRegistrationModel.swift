//
//  StaffRegistrationModel.swift
//  FleetManagementSystem
//
//  Clean model: handles UI state, validation, licence parsing.
//  Backend work is handled by Edge Function.
//

import Foundation
import Combine
import UIKit
import Vision
import Storage
import Supabase

// MARK: - Role

enum StaffRole: String, CaseIterable, Identifiable {
    case driver      = "Driver"
    case maintenance = "Maintenance"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .driver:      return "car.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        }
    }

    var description: String {
        switch self {
        case .driver:
            return "Manages vehicle operations and deliveries"
        case .maintenance:
            return "Handles vehicle maintenance and repairs"
        }
    }

    var dbValue: String {
        switch self {
        case .driver:      return "driver"
        case .maintenance: return "maintenance"
        }
    }
}

// MARK: - Model

class StaffRegistrationModel: ObservableObject {

    // MARK: Step 1 — Basic Info

    @Published var firstName:    String     = ""
    @Published var lastName:     String     = ""
    @Published var email:        String     = ""
    @Published var phoneNo:      String     = ""
    @Published var selectedRole: StaffRole? = nil

    // MARK: Driver-specific

    @Published var licenceImage: UIImage? = nil {
        didSet {
            if let img = licenceImage {
                extractLicenceData(from: img)
            } else {
                licenceNumber = ""
                licenceExpiryDate = ""
            }
        }
    }

    @Published var licenceNumber: String = ""
    @Published var licenceExpiryDate: String = ""

    // MARK: UI State

    @Published var currentStep:       Int     = 1
    @Published var licenceImageURL:    String? = nil
    @Published var isCreatingAccount: Bool    = false
    @Published var accountCreated:    Bool    = false
    @Published var errorMessage:      String? = nil

    // MARK: - Storage Upload

    func uploadLicenceImage() async throws -> String? {
        guard let image = licenceImage,
              let data = image.jpegData(compressionQuality: 0.5) else {
            return nil
        }

        let fileName = "licence_\(UUID().uuidString).jpg"
        let bucket = "staff-licences"

        try await SupabaseManager.shared.client.storage
            .from(bucket)
            .upload(
                path: fileName,
                file: data,
                options: FileOptions(contentType: "image/jpeg")
            )

        // Generate public URL (assuming bucket is public or we use public URL pattern)
        // If bucket is private, we should use a signed URL or just the path.
        // For simplicity in this flow, we'll use the public URL format.
        let publicURL = "\(SupabaseConfig.url)/storage/v1/object/public/\(bucket)/\(fileName)"
        self.licenceImageURL = publicURL
        return publicURL
    }

    // MARK: Computed

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    // MARK: Validation

    var isFormValid: Bool {
        guard
            !firstName.trimmingCharacters(in: .whitespaces).isEmpty,
            !lastName.trimmingCharacters(in: .whitespaces).isEmpty,
            isValidEmail(email),
            let role = selectedRole
        else {
            return false
        }

        if role == .driver {
            return licenceImage != nil &&
                   !licenceNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !licenceExpiryDate.trimmingCharacters(in: .whitespaces).isEmpty
        }

        return true
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }

    // MARK: Licence OCR

    private func extractLicenceData(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else { return }

            let recognizedStrings = observations.compactMap {
                $0.topCandidates(1).first?.string
            }

            DispatchQueue.main.async {
                self?.parseExtractedText(recognizedStrings)
            }
        }

        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func parseExtractedText(_ lines: [String]) {
        let datePattern = "(\\d{2}[/-]\\d{2}[/-]\\d{2,4})"

        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Extract expiry date
            if licenceExpiryDate.isEmpty,
               let range = cleanLine.range(of: datePattern, options: .regularExpression) {
                licenceExpiryDate = String(cleanLine[range])
            }

            // Extract licence number
            let noSpaces = cleanLine.replacingOccurrences(of: " ", with: "")
            let alphanumericPattern = "^[A-Z0-9]{6,20}$"

            if licenceNumber.isEmpty,
               noSpaces.range(of: alphanumericPattern, options: .regularExpression) != nil,
               noSpaces.range(of: datePattern, options: .regularExpression) == nil,
               !noSpaces.lowercased().contains("licence"),
               !noSpaces.lowercased().contains("driver"),
               !noSpaces.lowercased().contains("state") {

                licenceNumber = noSpaces
            }
        }
    }

    // MARK: Date Conversion

    func parsedExpiryDateForDB() -> String? {
        let formatter = DateFormatter()
        let formats = [
            "dd/MM/yyyy", "dd-MM-yyyy",
            "MM/dd/yyyy", "MM-dd-yyyy",
            "dd/MM/yy", "yyyy-MM-dd"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: licenceExpiryDate) {
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            }
        }

        return nil
    }

    // MARK: Reset

    func reset() {
        firstName         = ""
        lastName          = ""
        email             = ""
        phoneNo           = ""
        selectedRole      = nil
        licenceImage      = nil
        licenceNumber     = ""
        licenceExpiryDate = ""
        currentStep       = 1
        isCreatingAccount = false
        accountCreated    = false
        errorMessage      = nil
    }
}
