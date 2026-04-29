import Foundation
import Supabase
import Combine
import SwiftUI

/// Parses voice transcript into structured trip log fields and saves to Supabase.
@MainActor
final class VoiceTripLogViewModel: ObservableObject {
    
    let trip: TripMap
    
    // Parsed / editable fields
    @Published var startTime: String = ""
    @Published var endTime: String = ""
    @Published var location: String = ""
    @Published var mileage: String = ""
    
    // State
    @Published var isSaving: Bool = false
    @Published var saveSuccess: Bool = false
    @Published var errorMessage: String?
    
    init(trip: TripMap) {
        self.trip = trip
    }
    
    // MARK: - Parse Transcript
    
    func parseTranscript(_ transcript: String) {
        let text = transcript.lowercased()
        
        startTime = extractTime(from: text, keywords: ["started at", "start time", "began at", "departed at", "left at"]) ?? startTime
        endTime = extractTime(from: text, keywords: ["ended at", "end time", "finished at", "arrived at", "reached at"]) ?? endTime
        location = extractLocation(from: text) ?? location
        mileage = extractNumber(from: text, keywords: ["mileage", "odometer", "reading", "km", "miles", "kilometer"]) ?? mileage
    }
    
    // MARK: - Time Extraction
    
    private func extractTime(from text: String, keywords: [String]) -> String? {
        for keyword in keywords {
            guard let range = text.range(of: keyword) else { continue }
            let after = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            // Match patterns like "9:30 AM", "9 30 AM", "9:30", "930", "9 AM"
            let patterns = [
                // 9:30 AM / 9:30 PM
                "\\d{1,2}:\\d{2}\\s*(?:am|pm|a\\.m\\.|p\\.m\\.)",
                // 9 30 AM (spoken as separate words)
                "\\d{1,2}\\s+\\d{2}\\s*(?:am|pm|a\\.m\\.|p\\.m\\.)",
                // 9 AM / 10 PM
                "\\d{1,2}\\s*(?:am|pm|a\\.m\\.|p\\.m\\.)",
                // 9:30 (24h)
                "\\d{1,2}:\\d{2}",
            ]
            
            for pattern in patterns {
                if let match = after.range(of: pattern, options: .regularExpression) {
                    var result = String(after[match]).trimmingCharacters(in: .whitespaces)
                    // Normalize "9 30 am" → "9:30 AM"
                    result = result.replacingOccurrences(of: "a.m.", with: "AM")
                    result = result.replacingOccurrences(of: "p.m.", with: "PM")
                    result = result.uppercased().replacingOccurrences(of: "AM", with: " AM").replacingOccurrences(of: "PM", with: " PM")
                    result = result.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
                    return result
                }
            }
        }
        return nil
    }
    
    // MARK: - Location Extraction
    
    private func extractLocation(from text: String) -> String? {
        let keywords = ["from", "at location", "location is", "location", "in", "near"]
        
        for keyword in keywords {
            guard let range = text.range(of: keyword) else { continue }
            let after = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            // Take words until we hit a stop keyword or punctuation
            let stopWords = Set(["mileage", "odometer", "reading", "started", "ended", "start", "end", "km", "miles", "kilometer"])
            var words: [String] = []
            
            for word in after.components(separatedBy: .whitespaces) {
                let clean = word.trimmingCharacters(in: .punctuationCharacters)
                if stopWords.contains(clean) || clean.isEmpty { break }
                // Stop if we hit a number (likely mileage)
                if Double(clean) != nil && words.count > 0 { break }
                words.append(clean)
                if words.count >= 5 { break } // Cap at 5 words for location
            }
            
            if !words.isEmpty {
                return words.joined(separator: " ").capitalized
            }
        }
        return nil
    }
    
    // MARK: - Number Extraction
    
    private func extractNumber(from text: String, keywords: [String]) -> String? {
        for keyword in keywords {
            guard let range = text.range(of: keyword) else { continue }
            
            // Search both before and after the keyword
            let after = String(text[range.upperBound...])
            let before = String(text[..<range.lowerBound])
            
            // Look after keyword first
            if let match = after.range(of: "\\d[\\d,\\.]*", options: .regularExpression) {
                let num = after[match].replacingOccurrences(of: ",", with: "")
                if Double(num) != nil { return num }
            }
            
            // Then look before keyword
            let beforeWords = before.components(separatedBy: .whitespaces).reversed()
            for word in beforeWords {
                let clean = word.trimmingCharacters(in: .punctuationCharacters).replacingOccurrences(of: ",", with: "")
                if Double(clean) != nil { return clean }
            }
        }
        return nil
    }
    
    // MARK: - Save to Supabase
    
    func saveLog() async {
        isSaving = true
        errorMessage = nil
        
        defer { isSaving = false }
        
        do {
            var updates: [String: String] = [:]
            
            if !location.trimmingCharacters(in: .whitespaces).isEmpty {
                updates["start_location"] = location
            }
            
            if let mileageValue = Double(mileage.replacingOccurrences(of: ",", with: "")), mileageValue > 0 {
                updates["distance_travelled"] = String(mileageValue)
            }
            
            // Save voice log notes with all parsed data
            var logParts: [String] = []
            if !startTime.isEmpty { logParts.append("Start: \(startTime)") }
            if !endTime.isEmpty { logParts.append("End: \(endTime)") }
            if !location.isEmpty { logParts.append("Location: \(location)") }
            if !mileage.isEmpty { logParts.append("Mileage: \(mileage)") }
            
            if !logParts.isEmpty {
                updates["notes"] = "🎤 Voice Log — " + logParts.joined(separator: " | ")
            }
            
            guard !updates.isEmpty else {
                errorMessage = "No data to save. Please speak your trip details."
                return
            }
            
            try await SupabaseManager.shared.client
                .from("trips")
                .update(updates)
                .eq("trip_id", value: trip.id.uuidString)
                .execute()
            
            saveSuccess = true
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
