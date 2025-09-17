import SwiftUI
import AVFoundation
import UIKit

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
        
        init(_ parent: CameraBarcodeScannerView) {
            self.parent = parent
        }
        
        func didScanBarcode(_ code: String) {
            parent.scannedCode = code
            parent.isScanning = false
            parent.isPresented = false
        }
    }
}

