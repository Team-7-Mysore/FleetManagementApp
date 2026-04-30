import UIKit

extension UIImage {
    /// Resizes the image to a maximum dimension while maintaining aspect ratio
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage? {
        let originalSize = self.size
        
        // If image is already smaller than maxDimension, return self
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            return self
        }
        
        let ratio: CGFloat
        if originalSize.width > originalSize.height {
            ratio = maxDimension / originalSize.width
        } else {
            ratio = maxDimension / originalSize.height
        }
        
        let newSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Use actual pixels
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
