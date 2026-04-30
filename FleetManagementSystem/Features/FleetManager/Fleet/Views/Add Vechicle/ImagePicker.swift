import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .camera
    var onImagePicked: (UIImage) -> Void
    var onPDFPicked: ((URL) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> UIViewController {
        if sourceType == .photoLibrary || sourceType == .savedPhotosAlbum {
            var config = PHPickerConfiguration()
            config.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        } else {
            let picker = UIImagePickerController()
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                picker.sourceType = .camera
            } else {
                picker.sourceType = .photoLibrary
            }
            picker.delegate = context.coordinator
            return picker
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onPDFPicked: onPDFPicked)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHPickerViewControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        var onPDFPicked: ((URL) -> Void)?
        
        init(onImagePicked: @escaping (UIImage) -> Void, onPDFPicked: ((URL) -> Void)?) {
            self.onImagePicked = onImagePicked
            self.onPDFPicked = onPDFPicked
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            // Check if PDF
            if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".pdf")
                
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, error in
                    if let sourceURL = url {
                        do {
                            try FileManager.default.copyItem(at: sourceURL, to: tempFile)
                            DispatchQueue.main.async {
                                self.onPDFPicked?(tempFile)
                            }
                        } catch {
                            print("Error copying PDF: \(error)")
                        }
                    }
                }
                return
            }
            
            // Otherwise check if image
            guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                if let img = image as? UIImage {
                    DispatchQueue.main.async {
                        self?.onImagePicked(img)
                    }
                }
            }
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}