//
//  BarcodeScannerView.swift
//  norrish
//
//  Created by myftiu on 06/09/25.
//

import SwiftUI
import AVFoundation
import SwiftData

struct BarcodeScannerView: View {
        @Binding var scannedCode: String?
        @Binding var isScanning: Bool
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var modelContext
        @StateObject private var viewModel = BarcodeScannerViewModel()
        @State private var selectedProduct: Product?
        @State private var showingProductDetail = false
        @State private var showingCamera = false
        @State private var showingProductNotFound = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Scan")
                            .font(AppFonts.serif(32, weight: .bold))
                            .foregroundColor(.midnightSpruce)
                        
                        Spacer()
                        
                        Button(action: {
                            // Settings action
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.nordicSlate)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                    
                    // Scan Section
                    VStack(spacing: 24) {
                        // Scan Icon and Content
                        VStack(spacing: 24) {
                            // Large scan area
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.cardSurface)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.cardBorder, lineWidth: 1))
                                    .frame(height: 300)
                                
                                VStack(spacing: 20) {
                                    // Barcode icon in circle
                                    ZStack {
                                        Circle()
                                            .fill(Color.momentumAmber.opacity(0.15))
                                            .frame(width: 120, height: 120)
                                        
                                        Image(systemName: "barcode.viewfinder")
                                            .font(.system(size: 60))
                                            .foregroundColor(.momentumAmber)
                                    }
                                    
                                    VStack(spacing: 8) {
                                        Text("Scan a Product")
                                            .font(AppFonts.serif(22, weight: .semibold))
                                            .foregroundColor(.midnightSpruce)
                                        
                                        Text("Center the barcode in the frame to get started.")
                                            .font(AppFonts.sans(13, weight: .regular))
                                            .foregroundColor(.nordicSlate)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                            
                            // Start Scanning Button
                            Button(action: {
                                showingCamera = true
                                isScanning = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.title3)
                                    Text("Start Scanning")
                                        .font(AppFonts.sans(14, weight: .semibold))
                                }
                                .foregroundColor(.nordicBone)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.midnightSpruce)
                                .cornerRadius(28)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    
                    // Your Dashboard: generated, swipable recommendations
                    DashboardInsightsView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    
                    // Recent Scans Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Recent Scans")
                            .font(AppFonts.serif(20, weight: .bold))
                            .foregroundColor(.midnightSpruce)
                            .padding(.horizontal, 20)
                        
                        if viewModel.recentScans.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .font(.system(size: 40))
                                    .foregroundColor(.nordicSlate.opacity(0.7))
                                
                                Text("No recent scans")
                                    .font(AppFonts.sans(13, weight: .medium))
                                    .foregroundColor(.nordicSlate)
                                
                                Text("Start scanning products to see your history here")
                                    .font(AppFonts.sans(12, weight: .regular))
                                    .foregroundColor(.nordicSlate)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.recentScans) { scan in
                                    RecentScanRow(scan: scan, products: products) { product in
                                        selectedProduct = product
                                        showingProductDetail = true
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100) // Extra padding for bottom menu
                }
                .overlay(
                    // Loading overlay
                    Group {
                        if viewModel.isLoading {
                            AppLoadingOverlay(title: "Fetching product information...")
                        }
                    }
                )
                .sheet(item: $selectedProduct) { product in
                    ProductDetailView(product: product)
                }
                .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                    Button("OK") { }
                } message: {
                    Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
            .background(Color.nordicBone)
            .navigationBarHidden(true)
        }
            .sheet(isPresented: $showingCamera) {
                BarcodeCameraOverlayView(
                    scannedCode: $scannedCode,
                    isScanning: $isScanning,
                    isPresented: $showingCamera
                )
            }
            .fullScreenCover(isPresented: $showingProductNotFound) {
                ProductNotFoundView(
                    onClose: { showingProductNotFound = false },
                    onScanAgain: {
                        showingProductNotFound = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            showingCamera = true
                            isScanning = true
                        }
                    },
                    onAddManually: {
                        showingProductNotFound = false
                    },
                    onReport: {
                        showingProductNotFound = false
                    }
                )
            }
            .onChange(of: showingCamera) { old, new in
                if new == false { isScanning = false }
            }
            .onAppear {
                viewModel.loadRecentScans(from: products)
            }
            .onChange(of: scannedCode) { oldValue, newValue in
                guard let code = newValue else { return }
                Task {
                    viewModel.isLoading = true
                    defer { viewModel.isLoading = false }
                    do {
                        let product = try await viewModel.fetchProduct(
                            barcode: code,
                            existing: products,
                            modelContext: modelContext
                        )
                        selectedProduct = product
                        showingProductDetail = true
                    } catch {
                        if isNotFoundError(error) {
                            showingProductNotFound = true
                        }
                    }
                    viewModel.loadRecentScans(from: products)
                }
            }
        }
    }
    
    @Query(sort: \Product.scannedDate, order: .reverse) private var products: [Product]
    // Intentionally left without local fetch/load logic; handled by ViewModel

    private func isNotFoundError(_ error: Error) -> Bool {
        if case BackendAPIError.httpError(let statusCode, _) = error {
            return statusCode == 404
        }
        let normalized = error.localizedDescription.lowercased()
        return normalized.contains("404") || normalized.contains("not found")
    }
}
// RecentScan and RecentScanRow moved to Models/RecentScan.swift and Views/Components/RecentScanRow.swift

// MARK: - Original Scanner Logic (kept for camera functionality)
// Camera barcode UIKit controller moved to Scanning/Barcode/BarcodeScannerViewController.swift

// Preview-only: scanner landing screen with in-memory Product model context.
#Preview("Barcode Scanner") {
    BarcodeScannerView(
        scannedCode: .constant(nil),
        isScanning: .constant(false)
    )
    .modelContainer(for: Product.self, inMemory: true)
}
