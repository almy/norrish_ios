//
//  PersonalizedInsightCarousel.swift
//  norrish
//
//  Created by myftiu on 09/09/25.
//

import SwiftUI

// MARK: - Data Models
struct PersonalizedInsight {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let category: InsightCategory
    // Added fields to explain relation to user history
    var reason: String? = nil
    var evidence: [String] = []
    var tags: [String] = []
    
    enum InsightCategory {
        case preference
        case health
        case habit
        case recommendation
    }
}

// MARK: - Insight Data Service
class InsightDataService: ObservableObject {
    static let shared = InsightDataService()
    
    @Published var plateInsights: [PersonalizedInsight] = []
    @Published var scanInsights: [PersonalizedInsight] = []
    
    private init() {
        loadMockData()
    }
    
    private func loadMockData() {
        // Mock plate insights
        plateInsights = [
            PersonalizedInsight(
                icon: "carrot.fill",
                iconColor: .orange,
                title: "Veggie Lover",
                message: "You seem to like a lot of carrots! 🥕",
                category: .preference
            ),
            PersonalizedInsight(
                icon: "leaf.fill",
                iconColor: .green,
                title: "Healthy Choices",
                message: "Your meals are 85% healthier than average! 🌱",
                category: .health
            ),
            PersonalizedInsight(
                icon: "clock.fill",
                iconColor: .blue,
                title: "Dinner Pattern",
                message: "You usually eat dinner around 7 PM ⏰",
                category: .habit
            ),
            PersonalizedInsight(
                icon: "apple.logo",
                iconColor: .red,
                title: "Try Something New",
                message: "Add some berries for extra antioxidants! 🫐",
                category: .recommendation
            )
        ]
        
        // Mock scan insights
        scanInsights = [
            PersonalizedInsight(
                icon: "cup.and.saucer.fill",
                iconColor: .brown,
                title: "Coca-Cola Fan",
                message: "You seem to enjoy Coca-Cola frequently! 🥤",
                category: .preference
            ),
            PersonalizedInsight(
                icon: "checkmark.seal.fill",
                iconColor: .green,
                title: "Smart Scanner",
                message: "You've scanned 23 products this week! 📱",
                category: .habit
            ),
            PersonalizedInsight(
                icon: "exclamationmark.triangle.fill",
                iconColor: .orange,
                title: "Sugar Alert",
                message: "Consider low-sugar alternatives 🍯",
                category: .health
            ),
            PersonalizedInsight(
                icon: "heart.fill",
                iconColor: .red,
                title: "Heart Healthy",
                message: "Try products with less sodium 💖",
                category: .recommendation
            ),
            PersonalizedInsight(
                icon: "star.fill",
                iconColor: .yellow,
                title: "Top Brands",
                message: "You prefer organic brands 65% of the time ⭐",
                category: .preference
            )
        ]
    }
    
    // Method to add new insights based on user behavior
    func addInsight(_ insight: PersonalizedInsight, to category: InsightType) {
        switch category {
        case .plate:
            plateInsights.append(insight)
        case .scan:
            scanInsights.append(insight)
        }
    }
    
    enum InsightType {
        case plate
        case scan
    }
}

// MARK: - Carousel Component
struct PersonalizedInsightCarousel: View {
    let insights: [PersonalizedInsight]
    @State private var currentIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Dashboard")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                
                // Page indicators
                HStack(spacing: 4) {
                    ForEach(0..<insights.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            if !insights.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                        PersonalizedInsightCard(insight: insight)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 160)
                .animation(.easeInOut(duration: 0.5), value: currentIndex)
            } else {
                // Placeholder when no insights
                PersonalizedInsightCard(insight: PersonalizedInsight(
                    icon: "lightbulb.fill",
                    iconColor: .gray,
                    title: "Getting to know you",
                    message: "Keep using the app to see personalized insights!",
                    category: .preference
                ))
            }
        }
    }
}

// MARK: - Individual Insight Card
struct PersonalizedInsightCard: View {
    let insight: PersonalizedInsight
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(insight.iconColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: insight.icon)
                    .foregroundColor(insight.iconColor)
                    .font(.title2)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Tags from underlying recommendation/correlation
                if !insight.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(insight.tags, id: \.self) { tag in
                                Text(tag.replacingOccurrences(of: "_", with: " "))
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }

                // Brief causal line to connect to user data
                if let reason = insight.reason, !reason.isEmpty {
                    Text("Because: \(reason)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Show up to 2 pieces of evidence
                if !insight.evidence.isEmpty {
                    ForEach(Array(insight.evidence.prefix(2)), id: \.self) { ev in
                        Text("• \(ev)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Category badge
            Text(categoryText(for: insight.category))
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor(for: insight.category))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func categoryText(for category: PersonalizedInsight.InsightCategory) -> String {
        switch category {
        case .preference: return "TASTE"
        case .health: return "HEALTH"
        case .habit: return "HABIT"
        case .recommendation: return "TIP"
        }
    }
    
    private func categoryColor(for category: PersonalizedInsight.InsightCategory) -> Color {
        switch category {
        case .preference: return .blue
        case .health: return .green
        case .habit: return .purple
        case .recommendation: return .orange
        }
    }
}

// MARK: - Auto-rotating Carousel
struct AutoRotatingCarousel: View {
    let insights: [PersonalizedInsight]
    @State private var currentIndex = 0
    @State private var timer: Timer?
    
    var body: some View {
        PersonalizedInsightCarousel(insights: insights)
            .onAppear {
                startAutoRotation()
            }
            .onDisappear {
                stopAutoRotation()
            }
    }
    
    private func startAutoRotation() {
        guard insights.count > 1 else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = (currentIndex + 1) % insights.count
            }
        }
    }
    
    private func stopAutoRotation() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    VStack {
        PersonalizedInsightCarousel(insights: InsightDataService.shared.plateInsights)
            .padding()
        
        Divider()
        
        AutoRotatingCarousel(insights: InsightDataService.shared.scanInsights)
            .padding()
    }
}
