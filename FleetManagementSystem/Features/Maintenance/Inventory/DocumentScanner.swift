import SwiftUI
import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    @Binding var showScanner: Bool
    var onScanCompletion: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: DocumentScanner

        init(_ parent: DocumentScanner) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var scannedImages: [UIImage] = []
            for i in 0..<scan.pageCount {
                scannedImages.append(scan.imageOfPage(at: i))
            }
            parent.onScanCompletion(scannedImages)
            parent.showScanner = false
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.showScanner = false
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document Scanner Failed with error: \(error.localizedDescription)")
            parent.showScanner = false
        }
    }
}
