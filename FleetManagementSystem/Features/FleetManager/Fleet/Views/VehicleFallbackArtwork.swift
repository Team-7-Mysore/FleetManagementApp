import SwiftUI

struct VehicleFallbackArtwork: View {
    let vehicleType: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color(.systemGray5))

            VStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 72, weight: .regular))
                    .foregroundColor(Color(.systemGray))

                Text(labelText)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color(.systemGray))
            }
            .padding()
        }
    }

    private var normalizedType: String {
        vehicleType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private var iconName: String {
        switch normalizedType {
        case let type where type.contains("bike"), let type where type.contains("motor"):
            return "motorcycle.fill"
        case let type where type.contains("car"), let type where type.contains("sedan"), let type where type.contains("suv"):
            return "car.side.fill"
        default:
            return "truck.box.fill"
        }
    }

    private var labelText: String {
        switch normalizedType {
        case let type where type.contains("bike"), let type where type.contains("motor"):
            return "Bike"
        case let type where type.contains("car"), let type where type.contains("sedan"), let type where type.contains("suv"):
            return "Car"
        default:
            return "Truck"
        }
    }
}
