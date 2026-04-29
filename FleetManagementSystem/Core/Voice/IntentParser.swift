import Foundation
import Combine

enum VoiceIntent: Equatable {
    case startTrip
    case endTrip(mileage: Double?)
    case fuel(Double?)
    case issue(String)
    case unknown
    
    var displayText: String {
        switch self {
        case .startTrip: return "Start Trip"
        case .endTrip(let mileage): 
            if let m = mileage { return "End Trip (\(m) km)" }
            return "End Trip"
        case .fuel(let amount): 
            if let a = amount { return "Update Fuel (\(a) liters)" }
            return "Update Fuel"
        case .issue(let description): return "Report Issue: \(description)"
        case .unknown: return "Unknown Action"
        }
    }
}

struct IntentParser {
    static func parse(_ text: String) -> VoiceIntent {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !lowercased.isEmpty else { return .unknown }
        
        if lowercased.contains("start") {
            print("🧠 IntentParser: Detected startTrip")
            return .startTrip
        }
        
        if lowercased.contains("end") {
            let mileage = extractNumber(from: lowercased, after: "end")
            print("🧠 IntentParser: Detected endTrip with mileage: \(String(describing: mileage))")
            return .endTrip(mileage: mileage)
        }
        
        if lowercased.contains("fuel") {
            let amount = extractNumber(from: lowercased, after: "fuel")
            print("🧠 IntentParser: Detected fuel with amount: \(String(describing: amount))")
            return .fuel(amount)
        }
        
        // Anything else is an issue report
        print("🧠 IntentParser: Detected issue with text: \(text)")
        return .issue(text)
    }
    
    private static func extractNumber(from text: String, after keyword: String) -> Double? {
        guard let range = text.range(of: keyword) else { return nil }
        let substring = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
        
        // Simple regex to extract the first sequence of digits/decimals
        let regex = try? NSRegularExpression(pattern: "[0-9]+(?:\\.[0-9]+)?")
        if let match = regex?.firstMatch(in: substring, range: NSRange(substring.startIndex..., in: substring)),
           let numRange = Range(match.range, in: substring) {
            return Double(substring[numRange])
        }
        
        return nil
    }
}
