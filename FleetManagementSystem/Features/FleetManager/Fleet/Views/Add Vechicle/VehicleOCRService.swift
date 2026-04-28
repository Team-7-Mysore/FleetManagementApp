//
//  VehicleOCRService.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 28/04/26.
//


import Vision
import UIKit

class VehicleOCRService {

    static let shared = VehicleOCRService()

    // MAIN OCR FUNCTION
    func recognizeText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations.compactMap {
                    $0.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}