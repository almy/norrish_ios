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
            Color.nordicBone.opacity(0.6)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.04))

            VStack {
                Spacer(minLength: 24)
                scannerSurface
                Spacer(minLength: 32)
            }
        }
    }

    @ViewBuilder
    private var scannerSurface: some View {
        #if DEBUG && targetEnvironment(simulator)
        simulatorDebugSurface
        #else
        CameraBarcodeScannerView(
            scannedCode: $scannedCode,
            isScanning: $isScanning,
            isPresented: $isPresented
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 20)
        .frame(height: UIScreen.main.bounds.height * 0.6)
        #endif
    }

    #if DEBUG && targetEnvironment(simulator)
    private var simulatorDebugSurface: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.midnightSpruce)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("debug.barcode.title", comment: "Simulator barcode debug panel title"))
                            .font(AppFonts.serif(22, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                        Text(fixtureSourceLabel)
                            .font(AppFonts.sans(13, weight: .regular))
                            .foregroundColor(.nordicSlate)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Button(action: {
                    isScanning = false
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.midnightSpruce)
                        .frame(width: 32, height: 32)
                        .background(Color.cardSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("debug.barcode.close", comment: "Close simulator barcode debug panel"))
            }

            // Barcode list — external fixtures if available, fallback samples otherwise
            if ExternalBarcodeFixtureLoader.isAvailable {
                externalFixtureList
            } else {
                fallbackSampleList
            }

            Text(fixtureFooterLabel)
                .font(AppFonts.sans(11, weight: .regular))
                .foregroundColor(.nordicSlate.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nordicBone)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 20)
        .onAppear {
            // Auto-inject if PERSONA_NAME + FIXTURE_INDEX are set (automated persona runs).
            if let barcode = ExternalBarcodeFixtureLoader.autoInjectBarcode() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    injectDebugBarcode(barcode)
                }
            }
        }
    }

    /// External fixture list loaded from FIXTURE_PATH.
    private var externalFixtureList: some View {
        let items = ExternalBarcodeFixtureLoader.loadDisplayItems()
        return VStack(spacing: 10) {
            ForEach(items) { item in
                Button(action: {
                    injectDebugBarcode(item.barcode)
                }) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.label)
                                .font(AppFonts.sans(14, weight: .semibold))
                                .foregroundColor(.midnightSpruce)
                            Text(item.subtitle)
                                .font(AppFonts.sans(12, weight: .regular))
                                .foregroundColor(.nordicSlate)
                        }
                        Spacer()
                        Text(NSLocalizedString("debug.barcode.cta", comment: "Simulator barcode debug action"))
                            .font(AppFonts.sans(12, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Legacy fallback list using hardcoded samples.
    private var fallbackSampleList: some View {
        VStack(spacing: 10) {
            ForEach(DebugBarcodeFixtures.samples) { sample in
                Button(action: {
                    injectDebugBarcode(sample.barcode)
                }) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sample.name)
                                .font(AppFonts.sans(14, weight: .semibold))
                                .foregroundColor(.midnightSpruce)
                            Text("\(sample.brand) · \(sample.barcode)")
                                .font(AppFonts.sans(12, weight: .regular))
                                .foregroundColor(.nordicSlate)
                        }
                        Spacer()
                        Text(NSLocalizedString("debug.barcode.cta", comment: "Simulator barcode debug action"))
                            .font(AppFonts.sans(12, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var fixtureSourceLabel: String {
        if ExternalBarcodeFixtureLoader.isAvailable {
            if let persona = ExternalBarcodeFixtureLoader.personaName {
                return "External fixtures · \(persona.capitalized)"
            }
            return "External fixtures loaded"
        }
        return NSLocalizedString("debug.barcode.subtitle", comment: "Simulator barcode debug panel subtitle")
    }

    private var fixtureFooterLabel: String {
        if ExternalBarcodeFixtureLoader.isAvailable {
            return "Barcodes loaded from FIXTURE_PATH. Real backend lookup runs after selection."
        }
        return NSLocalizedString("debug.barcode.footer", comment: "Simulator barcode debug panel footer")
    }

    private func injectDebugBarcode(_ barcode: String) {
        scannedCode = barcode
        isScanning = false
        isPresented = false
    }
    #endif
}
