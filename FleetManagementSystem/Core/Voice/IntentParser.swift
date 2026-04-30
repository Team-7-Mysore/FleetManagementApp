import Foundation
import Combine

enum VoiceIntent: Equatable {
    case startTrip
    case endTrip(mileage: Double?)
    case fuel(Double?)
    case issue(description: String, category: String?, severity: String?) // ✅ UPDATED
    case unknown
    
    var displayText: String {
        switch self {
        case .startTrip:
            return "Start Trip"
            
        case .endTrip(let mileage):
            if let m = mileage { return "End Trip (\(m) km)" }
            return "End Trip"
            
        case .fuel(let amount):
            if let a = amount { return "Update Fuel (\(a) liters)" }
            return "Update Fuel"
            
        case .issue(let description, let category, let severity):
            return "Report Issue\n\(category ?? "Auto") | \(severity ?? "Auto")\n\(description)"
            
        case .unknown:
            return "Unknown Action"
        }
    }
}

struct IntentParser {
    
    static func parse(_ text: String) -> VoiceIntent {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !lowercased.isEmpty else { return .unknown }
        
        // START TRIP
        if lowercased.contains("start") {
            print("🧠 IntentParser: Detected startTrip")
            return .startTrip
        }
        
        // END TRIP
        if lowercased.contains("end") {
            let mileage = extractNumber(from: lowercased, after: "end")
            print("🧠 IntentParser: Detected endTrip with mileage: \(String(describing: mileage))")
            return .endTrip(mileage: mileage)
        }
        
        // FUEL
        if lowercased.contains("fuel") {
            let amount = extractNumber(from: lowercased, after: "fuel")
            print("🧠 IntentParser: Detected fuel with amount: \(String(describing: amount))")
            return .fuel(amount)
        }
        
        // ISSUE (SMART)
        if lowercased.contains("issue") || lowercased.contains("problem") {
            let category = detectCategory(lowercased)
            let severity = detectSeverity(lowercased)
            let description = cleanDescription(lowercased)
            
            print("🧠 IntentParser: Detected issue")
            print("   Category: \(category ?? "nil")")
            print("   Severity: \(severity ?? "nil")")
            print("   Description: \(description)")
            
            return .issue(
                description: description,
                category: category,
                severity: severity
            )
        }
        
        // DEFAULT → ISSUE (fallback)
        print("🧠 IntentParser: Defaulting to issue with text: \(text)")
        return .issue(
            description: text,
            category: detectCategory(lowercased),
            severity: detectSeverity(lowercased)
        )
    }
    
    // MARK: - CATEGORY DETECTION
    private static func detectCategory(_ text: String) -> String? {
        if text.contains("engine") || text.contains("brake") {
            return "Mechanical"
        }
        if text.contains("battery") || text.contains("light") {
            return "Electrical"
        }
        if text.contains("tyre") || text.contains("tire") || text.contains("puncture") {
            return "Tyre/Wheel"
        }
        if text.contains("leak") || text.contains("oil") {
            return "Fluid Leak"
        }
        if text.contains("dent") || text.contains("body") {
            return "Bodywork"
        }
        if text.contains("seatbelt") || text.contains("safety") {
            return "Safety"
        }
        return "Other"
    }
    
    // MARK: - SEVERITY DETECTION
    private static func detectSeverity(_ text: String) -> String? {
        if text.contains("critical") || text.contains("urgent") || text.contains("immediately") {
            return "Critical"
        }
        if text.contains("minor") || text.contains("small") {
            return "Low"
        }
        return "Medium"
    }
    
    // MARK: - CLEAN DESCRIPTION
    private static func cleanDescription(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "report issue", with: "")
            .replacingOccurrences(of: "issue", with: "")
            .replacingOccurrences(of: "problem", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - NUMBER EXTRACTION (UNCHANGED)
    private static func extractNumber(from text: String, after keyword: String) -> Double? {
        guard let range = text.range(of: keyword) else { return nil }
        let substring = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
        
        let regex = try? NSRegularExpression(pattern: "[0-9]+(?:\\.[0-9]+)?")
        if let match = regex?.firstMatch(in: substring, range: NSRange(substring.startIndex..., in: substring)),
           let numRange = Range(match.range, in: substring) {
            return Double(substring[numRange])
        }
        
        return nil
    }
}
