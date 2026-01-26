import SwiftUI
import AVFoundation
import UIKit
import SwiftData

protocol BarcodeScannerDelegate: AnyObject {
    func didScanBarcode(_ code: String)
}

struct CameraBarcodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, BarcodeScannerDelegate {
        let parent: CameraBarcodeScannerView
        private var isSubmitting = false
        private var lastCode: String?
        
        init(_ parent: CameraBarcodeScannerView) {
            self.parent = parent
        }
        
        func didScanBarcode(_ code: String) {
            // Prevent duplicate submissions
            if isSubmitting { return }
            isSubmitting = true
            lastCode = code
            DispatchQueue.main.async {
                // Reflect scanning state and keep the sheet up briefly for a smooth transition
                self.parent.scannedCode = code
                self.parent.isScanning = false
            }
            Task { [weak self] in
                guard let self else { return }
                // Immediately call backend to fetch product; locale can be device locale
                let locale = Locale.current.language.languageCode?.identifier ?? "en"
                do {
                    let response: BackendBarcodeResponse = try await BackendAPIClient.shared.post(
                        endpoint: BackendAPIClient.shared.endpoints.scanBarcode,
                        body: BackendBarcodeRequest(barcode: code, locale: locale)
                    )
                    // On success, close camera sheet smoothly
                    await MainActor.run {
                        // Dismiss the camera sheet with a slight delay to let UI show feedback
                        self.parent.isPresented = false
                    }
                    // Also propagate the scanned code back up; the parent view will present details
                } catch {
                    // Even on error, dismiss the camera and let parent handle error UI
                    await MainActor.run {
                        self.parent.isPresented = false
                    }
                }
            }
        }
    }
}

