import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct PDFPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fileURL: URL

    @State private var showShareSheet = false
    @State private var showExportSheet = false

    var body: some View {
        NavigationStack {
            PDFKitView(url: fileURL)
                .navigationTitle("Usage Report")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            showExportSheet = true
                        } label: {
                            Image(systemName: "arrow.down.circle")
                        }

                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [fileURL])
        }
        .sheet(isPresented: $showExportSheet) {
            ExportDocumentView(url: fileURL)
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document == nil {
            uiView.document = PDFDocument(url: url)
        }
    }
}

private struct ExportDocumentView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
