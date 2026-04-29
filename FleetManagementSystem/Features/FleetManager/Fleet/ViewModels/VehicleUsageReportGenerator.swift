import Foundation
import PDFKit
import UIKit

struct VehicleUsageTrip: Decodable, Identifiable {
    let tripId: UUID
    let tripName: String?
    let origin: String?
    let destination: String?
    let status: String?
    let pickupTime: String?
    let startTime: String?
    let endTime: String?
    let distanceTravelled: Double?
    let clientContact: String?
    var id: UUID { tripId }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case tripName = "trip_name"
        case origin
        case destination
        case status
        case pickupTime = "pickup_time"
        case startTime = "start_time"
        case endTime = "end_time"
        case distanceTravelled = "distance_travelled"
        case clientContact = "client_contact"
    }
}

enum VehicleUsageReportGenerator {
    static func generate(vehicle: Vehicle, trips: [VehicleUsageTrip]) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let margin: CGFloat = 36
        let contentWidth = pageRect.width - (margin * 2)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            var currentY = margin

            func beginPageIfNeeded(for requiredHeight: CGFloat) {
                if currentY + requiredHeight > pageRect.height - margin {
                    context.beginPage()
                    currentY = margin
                }
            }

            func drawText(_ text: String, font: UIFont, color: UIColor = .black, x: CGFloat? = nil, y: CGFloat, width: CGFloat? = nil) -> CGFloat {
                let resolvedX = x ?? margin
                let resolvedWidth = width ?? contentWidth
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph
                ]
                let rect = NSString(string: text).boundingRect(
                    with: CGSize(width: resolvedWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                NSString(string: text).draw(
                    in: CGRect(x: resolvedX, y: y, width: resolvedWidth, height: ceil(rect.height)),
                    withAttributes: attributes
                )
                return ceil(rect.height)
            }

            func formattedDate(_ raw: String?) -> String {
                guard let raw, !raw.isEmpty else { return "N/A" }

                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso.date(from: raw) {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    return formatter.string(from: date)
                }

                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                ]
                for format in formats {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: raw) {
                        let display = DateFormatter()
                        display.dateStyle = .medium
                        display.timeStyle = .short
                        return display.string(from: date)
                    }
                }

                return raw
            }

            func drawDivider(y: CGFloat) {
                context.cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
                context.cgContext.setLineWidth(1)
                context.cgContext.move(to: CGPoint(x: margin, y: y))
                context.cgContext.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
                context.cgContext.strokePath()
            }

            context.beginPage()

            currentY += drawText("Vehicle Usage Report", font: .boldSystemFont(ofSize: 24), y: currentY)
            currentY += 8
            currentY += drawText(vehicle.name, font: .systemFont(ofSize: 18, weight: .semibold), color: .darkGray, y: currentY)
            currentY += 6
            currentY += drawText("Plate: \(vehicle.registrationNumber)    Type: \(vehicle.vehicleType)", font: .systemFont(ofSize: 12), color: .darkGray, y: currentY)
            currentY += 4
            currentY += drawText("Generated: \(formattedDate(Date().ISO8601Format()))", font: .systemFont(ofSize: 11), color: .gray, y: currentY)
            currentY += 16

            let totalDistance = trips.reduce(0.0) { $0 + ($1.distanceTravelled ?? 0) }
            let completedTrips = trips.filter { ($0.status ?? "").lowercased() == "completed" }.count
            let activeTrips = trips.filter {
                let status = ($0.status ?? "").lowercased()
                return status == "in_progress" || status == "in transit" || status == "in_transit" || status == "assigned"
            }.count

            currentY += drawText("Summary", font: .boldSystemFont(ofSize: 16), y: currentY)
            currentY += 10
            currentY += drawText("Total Trips: \(trips.count)", font: .systemFont(ofSize: 13), y: currentY)
            currentY += 4
            currentY += drawText("Completed Trips: \(completedTrips)", font: .systemFont(ofSize: 13), y: currentY)
            currentY += 4
            currentY += drawText("Active / Assigned Trips: \(activeTrips)", font: .systemFont(ofSize: 13), y: currentY)
            currentY += 4
            currentY += drawText(String(format: "Total Distance: %.1f km", totalDistance), font: .systemFont(ofSize: 13), y: currentY)
            currentY += 18

            currentY += drawText("Trip History", font: .boldSystemFont(ofSize: 16), y: currentY)
            currentY += 12

            if trips.isEmpty {
                _ = drawText("No trips found for this vehicle.", font: .italicSystemFont(ofSize: 13), color: .gray, y: currentY)
            } else {
                for trip in trips {
                    beginPageIfNeeded(for: 130)

                    currentY += drawText(trip.tripName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? trip.tripName! : "Unnamed Trip", font: .boldSystemFont(ofSize: 14), y: currentY)
                    currentY += 4
                    currentY += drawText("Trip ID: \(trip.tripId.uuidString.prefix(8))", font: .systemFont(ofSize: 11), color: .gray, y: currentY)
                    currentY += 4
                    currentY += drawText("Route: \((trip.origin?.isEmpty == false ? trip.origin! : "N/A")) → \((trip.destination?.isEmpty == false ? trip.destination! : "N/A"))", font: .systemFont(ofSize: 12), y: currentY)
                    currentY += 4
                    currentY += drawText("Status: \((trip.status?.replacingOccurrences(of: "_", with: " ").capitalized) ?? "Unknown")", font: .systemFont(ofSize: 12), y: currentY)
                    currentY += 4
                    currentY += drawText("Pickup: \(formattedDate(trip.pickupTime))", font: .systemFont(ofSize: 12), y: currentY)
                    currentY += 4
                    currentY += drawText("Start: \(formattedDate(trip.startTime))", font: .systemFont(ofSize: 12), y: currentY)
                    currentY += 4
                    currentY += drawText("End: \(formattedDate(trip.endTime))", font: .systemFont(ofSize: 12), y: currentY)
                    currentY += 4
                    currentY += drawText(String(format: "Distance: %.1f km", trip.distanceTravelled ?? 0), font: .systemFont(ofSize: 12), y: currentY)
                    if let clientContact = trip.clientContact, !clientContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        currentY += 4
                        currentY += drawText("Client Contact: \(clientContact)", font: .systemFont(ofSize: 12), y: currentY)
                    }
                    currentY += 12
                    drawDivider(y: currentY)
                    currentY += 14
                }
            }
        }

        let safePlate = vehicle.registrationNumber.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Vehicle_Usage_Report_\(safePlate).pdf")
        try data.write(to: url)

        if let document = PDFDocument(url: url) {
            document.documentAttributes = [
                PDFDocumentAttribute.titleAttribute: "Vehicle Usage Report - \(vehicle.registrationNumber)"
            ]
            document.write(to: url)
        }

        return url
    }
}
