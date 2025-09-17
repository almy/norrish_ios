//
//  ProductDetailView.swift
//  healthScanner
//
//  Created by user on 09/09/25.
//

import SwiftUI
import SwiftData
import UIKit

struct ProductDetailView: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss
    @StateObject private var insightService = InsightDataService.shared
    @State private var currentInsightIndex = 0
    @State private var showNutriInfo = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(NSLocalizedString("product.details", comment: "Product details title"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Invisible spacer for centering
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Product Image
                VStack {
                    if let localPath = product.localImagePath, FileManager.default.fileExists(atPath: localPath), let uiImage = UIImage(contentsOfFile: localPath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if let productImageURL = product.imageURL, !productImageURL.isEmpty {
                        CachedAsyncImage(urlString: productImageURL, cacheKey: product.barcode)
                            .frame(maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 250)
                            .overlay(
                                Image(systemName: "cart")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                
                VStack(alignment: .leading, spacing: 24) {
                    // Product Name and Health Level
                    VStack(alignment: .leading, spacing: 12) {
                        Text(product.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 10) {
                            NutriScoreBadge(letter: product.nutriScoreLetter, compact: true)
                            Button {
                                showNutriInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .sheet(isPresented: $showNutriInfo) {
                        NutriScoreInfoView(
                            productBreakdown: computeNutriScoreBreakdown(product.nutritionData, categories: product.categoriesTags),
                            plateScore: nil
                        )
                    }
                    
                    // Nutrition Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("nutrition.information", comment: "Nutrition information section title"))
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            NutritionCard(
                                title: NSLocalizedString("nutrition.calories", comment: "Calories nutrition label"),
                                value: "\(product.nutritionData.calories)",
                                unit: NSLocalizedString("unit.kilocalories", comment: "Kilocalories unit"),
                                color: .orange
                            )
                            
                            NutritionCard(
                                title: NSLocalizedString("nutrition.fat", comment: "Fat nutrition label"),
                                value: String(format: "%.1f", product.nutritionData.fat),
                                unit: NSLocalizedString("unit.grams", comment: "Grams unit"),
                                color: .red
                            )
                            
                            NutritionCard(
                                title: NSLocalizedString("nutrition.carbs", comment: "Carbohydrates nutrition label"),
                                value: String(format: "%.1f", product.nutritionData.carbohydrates),
                                unit: NSLocalizedString("unit.grams", comment: "Grams unit"),
                                color: .blue
                            )
                            
                            NutritionCard(
                                title: NSLocalizedString("nutrition.protein", comment: "Protein nutrition label"),
                                value: String(format: "%.1f", product.nutritionData.protein),
                                unit: NSLocalizedString("unit.grams", comment: "Grams unit"),
                                color: .green
                            )
                            
                            NutritionCard(
                                title: NSLocalizedString("nutrition.fiber", comment: "Fiber nutrition label"),
                                value: String(format: "%.1f", product.nutritionData.fiber),
                                unit: NSLocalizedString("unit.grams", comment: "Grams unit"),
                                color: .brown
                            )
                            
                            NutritionCard(
                                title: NSLocalizedString("nutrition.sugar", comment: "Sugar nutrition label"),
                                value: String(format: "%.1f", product.nutritionData.sugar),
                                unit: NSLocalizedString("unit.grams", comment: "Grams unit"),
                                color: .pink
                            )
                        }
                    }
                    
                    // Personalized Insights
                    PersonalizedInsightCarousel(insights: [
                        PersonalizedInsight(
                            icon: "heart.fill",
                            iconColor: .red,
                            title: "Heart Health",
                            message: "This product is low in saturated fats, which is great for your heart health goals!",
                            category: .health
                        ),
                        PersonalizedInsight(
                            icon: "leaf.fill",
                            iconColor: .green,
                            title: "Natural Choice",
                            message: "Based on your preferences, this product has minimal artificial ingredients.",
                            category: .preference
                        )
                    ])
                        .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            print("[ProductDetailView] Appeared for barcode=\(product.barcode) name=\(product.name) brand=\(product.brand) imageURL=\(product.imageURL ?? "nil") localImagePath=\(product.localImagePath ?? "nil")")
            if product.localImagePath == nil, let path = ImageCacheService.shared.cachedFilePath(forKey: product.barcode) {
                product.localImagePath = path
                print("[ProductDetailView] Set missing localImagePath=\(path)")
            }
        }
        .navigationBarHidden(true)
    }
}

// CachedAsyncImage moved to Views/Components/CachedAsyncImage.swift
