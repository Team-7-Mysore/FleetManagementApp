import SwiftUI
import PDFKit

@MainActor
class PDFCreator {
    static func createFlyer(view: some View, fileName: String) -> URL? {
        // 1. Setup the Hosting Controller
        let controller = UIHostingController(rootView: view)
        let viewToRender = controller.view
        
        // 2. Define Page Size (A4)
        let pageSize = CGSize(width: 595.2, height: 841.8)
        
        // 3. Calculate Total Height
        let targetSize = CGSize(width: pageSize.width, height: .greatestFiniteMagnitude)
        let totalHeight = viewToRender?.sizeThatFits(targetSize).height ?? pageSize.height
        
        // 4. Set Frame
        viewToRender?.frame = CGRect(origin: .zero, size: CGSize(width: pageSize.width, height: totalHeight))
        viewToRender?.backgroundColor = .white
        
        // 5. Prepare PDF Renderer
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: pageSize), nil)
        
        var currentY: CGFloat = 0
        while currentY < totalHeight {
            UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: pageSize), nil)
            guard let context = UIGraphicsGetCurrentContext() else { break }
            
            // Shift the drawing context up to show the "next" section of the view
            context.translateBy(x: 0, y: -currentY)
            viewToRender?.layer.render(in: context)
            
            currentY += pageSize.height
        }
        
        UIGraphicsEndPDFContext()
        
        // 6. Save to Temporary Directory
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).pdf")
        do {
            try pdfData.write(to: url)
            return url
        } catch {
            print("PDF Error: \(error)")
            return nil
        }
    }
}
