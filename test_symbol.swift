import Foundation
import AppKit

if #available(macOS 11.0, *) {
    let img = NSImage(systemSymbolName: "car.slash", accessibilityDescription: nil)
    print("car.slash exists: \(img != nil)")
} else {
    print("macOS too old")
}
