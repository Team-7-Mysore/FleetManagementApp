//
//  ImagePicker.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 17/04/26.
//


import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    
    var onPick: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        
        let onPick: (UIImage) -> Void
        
        init(onPick: @escaping (UIImage) -> Void) {
            self.onPick = onPick
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let item = results.first?.itemProvider,
                  item.canLoadObject(ofClass: UIImage.self) else { return }
            
            item.loadObject(ofClass: UIImage.self) { image, _ in
                if let img = image as? UIImage {
                    DispatchQueue.main.async {
                        self.onPick(img)
                    }
                }
            }
        }
    }
}
