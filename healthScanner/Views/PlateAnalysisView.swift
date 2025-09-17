// PlateAnalysisView.swift — AR Scanner Integrated (fixed)
// - Uses ARPlateScannerView for simulator & device (no LiveARPlateScannerView).
// - Maps ARPlateScanNutrition -> PlateAnalysis.
// - Sends photo + metadata to OpenAIService and (optionally) appends AI text as an Insight.

import SwiftUI
import PhotosUI
import SwiftData
import UIKit
#if canImport(ARKit)
import ARKit
#endif

struct PlateAnalysisView: View {
    // MARK: State
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PlateAnalysisViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingARScanner = false
    @State private var showingAnalysis = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 28) {
                        cameraPreview
                        actionButtons
                        tips
                        if viewModel.lastAnalysisResult != nil { reopenLastSection }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear { viewModel.loadLastAnalysisFromDefaults() }
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadPickedImage(newItem) }
        }
        .sheet(isPresented: $showingARScanner) {
            // Single entry point (simulator & device)
            ARPlateScannerView { scan, capturedImage in
                showingARScanner = false
                // Small delay avoids showing stale camera frame under the result sheet animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    handleScanResult(scan: scan, image: capturedImage)
                }
            } onCancel: {
                showingARScanner = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingAnalysis) {
            if let analysis = viewModel.analysisResult {
                PlateAnalysisResultView(
                    analysis: analysis,
                    image: viewModel.lastAnalyzedImage,
                    onStartNewScan: { resetAfterAnalysis() },
                    onClose: { showingAnalysis = false }
                )
            }
        }
    }
}

// MARK: - Subviews
private extension PlateAnalysisView {
    var header: some View {
        HStack {
            Text("What's on your plate?").font(.title2).fontWeight(.bold)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    var cameraPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.orange.opacity(0.08))
                .frame(height: 300)
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 56))
                        .foregroundColor(.mint)
                    Text("Center your plate and move a little when scanning")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
    }

    var actionButtons: some View {
        VStack(spacing: 14) {
            Button { showingARScanner = true } label: {
                HStack { Image(systemName: "camera.viewfinder"); Text("Scan with AR") }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.indigo)
                    .cornerRadius(24)
            }
            .padding(.horizontal, 20)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack { Image(systemName: "photo.on.rectangle"); Text("Choose from Gallery") }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(24)
            }
            .padding(.horizontal, 20)

            if viewModel.isAnalyzing { ProgressView("Analyzing…").padding(.top, 4) }
        }
    }

    var tips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pro tip").font(.footnote).fontWeight(.semibold)
            Text("For best accuracy, move slightly left/right and let the app say ‘Hold still’ before capture.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    var reopenLastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Previous Analysis")
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(.secondary)
            Button {
                if let last = viewModel.lastAnalysisResult {
                    viewModel.analysisResult = last
                    selectedImage = viewModel.lastAnalyzedImage
                    showingAnalysis = true
                }
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Reopen Results")
                }
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.mint)
                .cornerRadius(20)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Helpers & Processing
private extension PlateAnalysisView {
    func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard
            let item,
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }
        selectedImage = image
        // Optionally: run static analysis for gallery image here.
    }

    func nutritionScore(for scan: ARPlateScanNutrition) -> Double {
        let macroSum = Double(scan.protein + scan.carbs + scan.fat)
        return min(10, max(0, macroSum / 30.0 * 10.0))
    }

    func resetAfterAnalysis() {
        selectedImage = nil
        selectedItem = nil
        viewModel.isAnalyzing = false
        viewModel.analysisResult = nil
        showingAnalysis = false
    }

    /// Unified handler for both simulator and device scans
    func handleScanResult(scan: ARPlateScanNutrition, image: UIImage) {
        // Keep showing the captured photo during analysis
        withAnimation { selectedImage = image }
        Task { @MainActor in
            await viewModel.handleScanResult(scan: scan, image: image, modelContext: modelContext)
            showingAnalysis = true
        }
    }
}
 
