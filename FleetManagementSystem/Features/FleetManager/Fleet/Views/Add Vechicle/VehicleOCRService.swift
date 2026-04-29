//
//  VehicleOCRService.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 28/04/26.
//

import Vision
import UIKit
import PDFKit

class VehicleOCRService {

    static let shared = VehicleOCRService()

    // MAIN OCR FUNCTION - handles both images and PDFs
    func recognizeText(from source: Any) async -> String {
        if let image = source as? UIImage {
            return await recognizeTextFromImage(image)
        } else if let url = source as? URL, url.pathExtension.lowercased() == "pdf" {
            return await recognizeTextFromPDF(url: url)
        }
        return ""
    }

    // Handle UIImage (scanned documents)
    func recognizeTextFromImage(_ image: UIImage) async -> String {
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

    // Handle PDF files - extract text directly
    func recognizeTextFromPDF(url: URL) async -> String {
        guard let document = PDFDocument(url: url) else { 
            print("PDF: Could not load PDF document")
            return ""
        }

        var allText = ""
        let pageCount = document.pageCount
        print("PDF: Loaded document with \(pageCount) pages")

        for i in 0..<pageCount {
            if let page = document.page(at: i),
               let pageText = page.string {
                print("PDF: Page \(i) text length: \(pageText.count)")
                allText += pageText + "\n"
            }
        }

        if !allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("PDF: Total extracted text: \(allText.prefix(200))")
            return allText
        }

        print("PDF: No embedded text found, falling back to page image OCR")

        var ocrText = ""
        for i in 0..<pageCount {
            guard let page = document.page(at: i),
                  let image = renderImage(from: page) else { continue }
            let pageOCRText = await recognizeTextFromImage(image)
            if !pageOCRText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ocrText += pageOCRText + "\n"
            }
        }

        print("PDF: OCR fallback extracted text: \(ocrText.prefix(200))")
        return ocrText
    }

    // Also support file URL from tmp directory
    func recognizeText(from fileURL: URL) async -> String {
        let fileExtension = fileURL.pathExtension.lowercased()

        if fileExtension == "pdf" {
            return await recognizeTextFromPDF(url: fileURL)
        } else if fileExtension == "jpg" || fileExtension == "jpeg" || fileExtension == "png" || fileExtension == "heic" {
            guard let image = UIImage(contentsOfFile: fileURL.path) else { return "" }
            return await recognizeTextFromImage(image)
        }

        return ""
    }

    private func renderImage(from page: PDFPage) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale: CGFloat = 2.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: bounds.width * scale, height: bounds.height * scale)
        )

        return renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))

            context.cgContext.saveGState()
            context.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
    }
}
