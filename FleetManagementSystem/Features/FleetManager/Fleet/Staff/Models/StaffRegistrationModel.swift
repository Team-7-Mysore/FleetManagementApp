//
//  StaffRegistrationModel.swift
//  FleetManagementSystem
//
//  Data model for the Add Person / Staff onboarding flow.
//  Inserts directly into public.users via Supabase on confirm.
//

import Foundation
import Combine
import UIKit
import Supabase
import Vision

// MARK: - Role

enum StaffRole: String, CaseIterable, Identifiable {
    case driver      = "Driver"
    case maintenance = "Maintenance Staff"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .driver:      return "car.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        }
    }

    var description: String {
        switch self {
        case .driver:      return "Manages vehicle operations and deliveries"
        case .maintenance: return "Handles vehicle maintenance and repairs"
        }
    }

    /// Matches the `user_role` enum values in the DB
    var dbValue: String {
        switch self {
        case .driver:      return "driver"
        case .maintenance: return "maintenance"
        }
    }
}

// MARK: - Supabase Insert Payload

private struct UserInsert: Encodable {
    let name:       String
    let email:      String
    let role:       String
    let phone_no:   String?
    let created_by: String
}

private struct DriverInsert: Encodable {
    let user_id:        String
    let license_no:     String
    let license_expiry: String
}

private struct InsertResponse: Decodable {
    let user_id: String
}

// MARK: - Model

class StaffRegistrationModel: ObservableObject {

    // Step 1 — Basic Info & Role
    @Published var firstName:    String     = ""
    @Published var lastName:     String     = ""
    @Published var email:        String     = ""
    @Published var phoneNo:      String     = ""
    @Published var selectedRole: StaffRole? = nil

    // Driver-only — licence photo picked from gallery
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

    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }

    private func extractLicenceData(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else { return }
            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
            
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
            
            if licenceExpiryDate.isEmpty, let range = cleanLine.range(of: datePattern, options: .regularExpression) {
                licenceExpiryDate = String(cleanLine[range])
            }
            
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

    private func parseDateForDB(_ dateString: String) -> String? {
        let formatter = DateFormatter()
        let formats = ["dd/MM/yyyy", "dd-MM-yyyy", "MM/dd/yyyy", "MM-dd-yyyy", "dd/MM/yy", "yyyy-MM-dd"]
        for fmt in formats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: dateString) {
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            }
        }
        return nil
    }

    // Navigation
    @Published var currentStep:       Int    = 1
    @Published var isCreatingAccount: Bool   = false
    @Published var accountCreated:    Bool   = false
    @Published var errorMessage:      String? = nil

    // MARK: Validation

    var isFormValid: Bool {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty,
              !lastName.trimmingCharacters(in: .whitespaces).isEmpty,
              isValidEmail(email),
              let role = selectedRole else { return false }
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

    // MARK: Account Creation — Supabase insert into public.users

    /// Admin UUID who is creating the staff account (derived from the authenticated user)
    private func fetchAdminUserId() async throws -> String {
        // Accessing Supabase auth session may be async/throwing and actor-isolated.
        // Use await/try to retrieve the current user id safely.
        let user = try await SupabaseManager.shared.client.auth.session.user
        return user.id.uuidString
    }

    func createAccount(completion: @escaping () -> Void) {
        guard let role = selectedRole else { return }

        isCreatingAccount = true
        errorMessage      = nil

        Task { @MainActor in
            do {
                let adminId: String
                do {
                    adminId = try await fetchAdminUserId()
                } catch {
                    isCreatingAccount = false
                    errorMessage = "No authenticated user. Please sign in again."
                    return
                }

                let payload = UserInsert(
                    name:       fullName,
                    email:      email.lowercased().trimmingCharacters(in: .whitespaces),
                    role:       role.dbValue,
                    phone_no:   phoneNo.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phoneNo.trimmingCharacters(in: .whitespaces),
                    created_by: adminId
                )

                let response: InsertResponse = try await SupabaseManager.shared.client
                    .from("users")
                    .insert(payload)
                    .select("user_id")
                    .single()
                    .execute()
                    .value

                // If driver, insert into `drivers` table
                if role == .driver {
                    guard let expiryDBFormat = parseDateForDB(licenceExpiryDate) else {
                        // If it fails down here, user is already created, but we can't save driver details.
                        // Throwing to show alert, though ideally we'd validate this in isFormValid.
                        throw NSError(domain: "AddStaff", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Licence Expiry Date format. Use DD/MM/YYYY."])
                    }
                    
                    let driverPayload = DriverInsert(
                        user_id: response.user_id,
                        license_no: licenceNumber.trimmingCharacters(in: .whitespaces),
                        license_expiry: expiryDBFormat
                    )
                    
                    try await SupabaseManager.shared.client
                        .from("drivers")
                        .insert(driverPayload)
                        .execute()
                }

                isCreatingAccount = false
                accountCreated    = true
                completion()
            } catch {
                isCreatingAccount = false
                errorMessage      = error.localizedDescription
            }
        }
    }

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

