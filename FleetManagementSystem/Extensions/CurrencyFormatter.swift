import Foundation

extension NumberFormatter {
    static var rupeeFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.currencySymbol = "₹"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

extension Double {
    func formattedAsRupee() -> String {
        return NumberFormatter.rupeeFormatter.string(from: NSNumber(value: self)) ?? "₹\(String(format: "%.2f", self))"
    }
}
