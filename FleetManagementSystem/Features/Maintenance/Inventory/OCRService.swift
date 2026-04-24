import UIKit
import Vision

class OCRService {
    static let shared = OCRService()

    func recognizeText(from image: UIImage) async throws -> (name: String, quantity: Int) {
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

    private func parseText(_ lines: [String]) -> (name: String, quantity: Int) {
        var quantity: Int = 1
        var name: String = ""

        // Process line by line
        for (index, line) in lines.enumerated() {
            let lowercasedLine = line.lowercased()

            // Look for quantity keywords
            if lowercasedLine.contains("qty") || lowercasedLine.contains("quantity") {
                // Try to extract digits from the same line
                let digits = line.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let parsedQty = Int(digits), parsedQty > 0 {
                    quantity = parsedQty
                }
                
                // If we didn't find digits, maybe check the next line for a standalone number
                if quantity == 1 && index + 1 < lines.count {
                    let nextLine = lines[index + 1]
                    let nextDigits = nextLine.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    if let parsedQty = Int(nextDigits), parsedQty > 0 {
                        quantity = parsedQty
                    }
                }

                // Consider the line before it as the part name if we don't have one yet
                if name.isEmpty && index > 0 {
                    let prevLine = lines[index - 1]
                    if !prevLine.isEmpty {
                        name = prevLine
                    }
                }
            }
        }

        // Fallback: If no keyword matched, but we still want to grab a potential part name (first meaningful line)
        if name.isEmpty {
            for line in lines {
                let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
                // Filter out common non-part names (Date, Invoice#, etc.) or check length
                if text.count > 3 && !text.lowercased().contains("invoice") && !text.lowercased().contains("date") {
                    name = text
                    break
                }
            }
        }

        return (name, quantity)
    }
}
