import UIKit
import Vision

class OCRService {
    static let shared = OCRService()

    func recognizeText(from image: UIImage) async throws -> (name: String, quantity: Int, costPerUnit: Double?) {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "OCRService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { (request, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: NSError(domain: "OCRService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No text found"]))
                    return
                }

                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                
                print("--- OCR RAW TEXT START ---")
                lines.forEach { print($0) }
                print("--- OCR RAW TEXT END ---")
                
                let result = self.parseText(lines)
                continuation.resume(returning: result)
            }
            request.recognitionLevel = .accurate

            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseText(_ lines: [String]) -> (name: String, quantity: Int, costPerUnit: Double?) {
        var quantity: Int = 1
        var name: String = ""
        var costPerUnit: Double? = nil
        var detectedTotal: Double? = nil

        let numericRegex = try? NSRegularExpression(pattern: "[0-9]+(?:\\.[0-9]{1,2})?", options: [])

        func extractFirstNumber(from text: String) -> Double? {
            let normalized = text.replacingOccurrences(of: "₹", with: "")
                                .replacingOccurrences(of: ",", with: "")
                                .replacingOccurrences(of: "inr", with: "", options: .caseInsensitive)
            
            let nsString = normalized as NSString
            let results = numericRegex?.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let range = results?.range {
                return Double(nsString.substring(with: range))
            }
            return nil
        }

        // 1. Process line by line for structured keywords
        for (index, line) in lines.enumerated() {
            let lowerLine = line.lowercased().trimmingCharacters(in: .whitespaces)

            // QUANTITY EXTRACTION
            if lowerLine.contains("qty") || lowerLine.contains("quantity") {
                if let val = extractFirstNumber(from: line) {
                    quantity = Int(val)
                } else if index + 1 < lines.count, let val = extractFirstNumber(from: lines[index + 1]) {
                    quantity = Int(val)
                }
            }

            // UNIT PRICE EXTRACTION
            let priceKeywords = ["unit price", "rate", "price", "unit cost", "cost"]
            if priceKeywords.contains(where: { lowerLine.contains($0) }) {
                if let val = extractFirstNumber(from: line) {
                    costPerUnit = val
                    print("✅ Found Unit Price in line: \(line) -> \(val)")
                } else if index + 1 < lines.count, let val = extractFirstNumber(from: lines[index + 1]) {
                    costPerUnit = val
                    print("✅ Found Unit Price in next line: \(lines[index + 1]) -> \(val)")
                }
            }
            
            // TOTAL VALUE EXTRACTION (for fallback)
            if lowerLine.contains("total") || lowerLine.contains("amount") {
                if let val = extractFirstNumber(from: line) {
                    detectedTotal = val
                }
            }
            
            // PART NAME HEURISTIC
            if name.isEmpty && (lowerLine.contains("item") || lowerLine.contains("part") || lowerLine.contains("desc")) {
                if index + 1 < lines.count {
                    name = lines[index + 1]
                }
            }
        }

        // 2. Fallback: Calculation Logic (Total / Quantity)
        if costPerUnit == nil, let total = detectedTotal, quantity > 0 {
            costPerUnit = total / Double(quantity)
            print("⚖️ Inferred Unit Price from Total: \(total) / \(quantity) = \(costPerUnit!)")
        }

        // 3. Fallback: Name discovery if keywords failed
        if name.isEmpty {
            for line in lines {
                let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowerText = text.lowercased()
                let noisyKeywords = ["invoice", "date", "bill", "address", "tax", "gst", "total", "phone", "email"]
                
                if text.count > 3 && !noisyKeywords.contains(where: { lowerText.contains($0) }) {
                    name = text
                    break
                }
            }
        }

        print("--- PARSED RESULTS ---")
        print("Name: \(name)")
        print("Quantity: \(quantity)")
        print("Unit Price: \(String(describing: costPerUnit))")
        
        return (name, quantity, costPerUnit)
    }
}
