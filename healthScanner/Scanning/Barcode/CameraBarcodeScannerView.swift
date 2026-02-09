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
    var shouldFetchBackend: Bool = false
    
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
                self.parent.isPresented = false
            }
        }
    }
}

struct BarcodeCameraOverlayView: View {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.white.opacity(0.35)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.02))

            VStack {
                Spacer(minLength: 24)
                CameraBarcodeScannerView(
                    scannedCode: $scannedCode,
                    isScanning: $isScanning,
                    isPresented: $isPresented
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
                .padding(.horizontal, 20)
                .frame(height: UIScreen.main.bounds.height * 0.6)
                Spacer(minLength: 32)
            }
        }
    }
}
