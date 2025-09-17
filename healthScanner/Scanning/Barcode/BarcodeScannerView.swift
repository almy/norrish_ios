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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Scan")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            // Settings action
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
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
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 300)
                                
                                VStack(spacing: 20) {
                                    // Barcode icon in circle
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 120, height: 120)
                                        
                                        Image(systemName: "barcode.viewfinder")
                                            .font(.system(size: 60))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    VStack(spacing: 8) {
                                        Text("Scan a Product")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        Text("Center the barcode in the frame to get started.")
                                            .font(.body)
                                            .foregroundColor(.secondary)
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
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.green)
                                .cornerRadius(28)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    
                    // Insight Carousel
                    PersonalizedInsightCarousel(insights: [
                        PersonalizedInsight(
                            icon: "lightbulb.fill",
                            iconColor: .yellow,
                            title: "Scan Smart",
                            message: "Look for products with fewer ingredients for healthier choices!",
                            category: .recommendation
                        ),
                        PersonalizedInsight(
                            icon: "heart.fill",
                            iconColor: .red,
                            title: "Health Tip",
                            message: "Products with less than 5g of sugar per serving are better for your heart.",
                            category: .health
                        ),
                        PersonalizedInsight(
                            icon: "leaf.fill",
                            iconColor: .green,
                            title: "Go Natural",
                            message: "Choose products with organic certifications when possible.",
                            category: .preference
                        )
                    ])
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    
                    // Recent Scans Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Recent Scans")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        
                        if viewModel.recentScans.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.6))
                                
                                Text("No recent scans")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                Text("Start scanning products to see your history here")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .overlay(
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .scaleEffect(1.5)
                                        Text("Fetching product information...")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    .padding(24)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(12)
                                )
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
                .navigationBarHidden(true)
            }
            .sheet(isPresented: $showingCamera) {
                CameraBarcodeScannerView(
                    scannedCode: $scannedCode,
                    isScanning: $isScanning,
                    isPresented: $showingCamera
                )
            }
            .onAppear {
                viewModel.loadRecentScans(from: products)
            }
            .onChange(of: scannedCode) { oldValue, newValue in
                if let code = newValue {
                    Task {
                        if let product = try? await viewModel.fetchProduct(barcode: code, existing: products, modelContext: modelContext) {
                            selectedProduct = product
                        }
                        viewModel.loadRecentScans(from: products)
                    }
                    dismiss()
                }
            }
        }
    }
    
    @Query(sort: \Product.scannedDate, order: .reverse) private var products: [Product]
    // Intentionally left without local fetch/load logic; handled by ViewModel
}
// RecentScan and RecentScanRow moved to Models/RecentScan.swift and Views/Components/RecentScanRow.swift

// MARK: - Original Scanner Logic (kept for camera functionality)
// Camera barcode UIKit controller moved to Scanning/Barcode/BarcodeScannerViewController.swift
