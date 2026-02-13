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
                iconColor: .momentumAmber,
                title: "Veggie Lover",
                message: "You seem to like a lot of carrots! 🥕",
                category: .preference
            ),
            PersonalizedInsight(
                icon: "leaf.fill",
                iconColor: .mossInsight,
                title: "Healthy Choices",
                message: "Your meals are 85% healthier than average! 🌱",
                category: .health
            ),
            PersonalizedInsight(
                icon: "clock.fill",
                iconColor: .midnightSpruce,
                title: "Dinner Pattern",
                message: "You usually eat dinner around 7 PM ⏰",
                category: .habit
            ),
            PersonalizedInsight(
                icon: "apple.logo",
                iconColor: .momentumAmber,
                title: "Try Something New",
                message: "Add some berries for extra antioxidants! 🫐",
                category: .recommendation
            )
        ]
        
        // Mock scan insights
        scanInsights = [
            PersonalizedInsight(
                icon: "cup.and.saucer.fill",
                iconColor: .midnightSpruce,
                title: "Coca-Cola Fan",
                message: "You seem to enjoy Coca-Cola frequently! 🥤",
                category: .preference
            ),
            PersonalizedInsight(
                icon: "checkmark.seal.fill",
                iconColor: .mossInsight,
                title: "Smart Scanner",
                message: "You've scanned 23 products this week! 📱",
                category: .habit
            ),
            PersonalizedInsight(
                icon: "exclamationmark.triangle.fill",
                iconColor: .momentumAmber,
                title: "Sugar Alert",
                message: "Consider low-sugar alternatives 🍯",
                category: .health
            ),
            PersonalizedInsight(
                icon: "heart.fill",
                iconColor: .momentumAmber,
                title: "Heart Healthy",
                message: "Try products with less sodium 💖",
                category: .recommendation
            ),
            PersonalizedInsight(
                icon: "star.fill",
                iconColor: .nordicSlate,
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
                    .font(AppFonts.serif(18, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                Spacer()
                
                // Page indicators
                HStack(spacing: 4) {
                    ForEach(0..<insights.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.momentumAmber : Color.nordicSlate.opacity(0.3))
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
                    iconColor: .nordicSlate,
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
                    .font(AppFonts.serif(16, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                
                Text(insight.message)
                    .font(AppFonts.sans(12, weight: .regular))
                    .foregroundColor(.nordicSlate)
                    .lineLimit(2)

                // Tags from underlying recommendation/correlation
                if !insight.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(insight.tags, id: \.self) { tag in
                                Text(tag.replacingOccurrences(of: "_", with: " "))
                                    .font(AppFonts.sans(9, weight: .bold))
                                    .foregroundColor(.nordicSlate)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.nordicBone.opacity(0.8))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }

                // Brief causal line to connect to user data
                if let reason = insight.reason, !reason.isEmpty {
                    Text("Because: \(reason)")
                        .font(AppFonts.sans(10, weight: .regular))
                        .foregroundColor(.nordicSlate)
                        .lineLimit(2)
                }

                // Show up to 2 pieces of evidence
                if !insight.evidence.isEmpty {
                    ForEach(Array(insight.evidence.prefix(2)), id: \.self) { ev in
                        Text("• \(ev)")
                            .font(AppFonts.sans(10, weight: .regular))
                            .foregroundColor(.nordicSlate)
                    }
                }
            }
            
            VStack(alignment: .trailing, spacing: 6) {
                // Arrow indicator based on message direction
                if insight.message.localizedCaseInsensitiveContains("up") {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.mossInsight)
                } else if insight.message.localizedCaseInsensitiveContains("down") {
                    Image(systemName: "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(.momentumAmber)
                }

                // Minimal sparkline using mock normalization if we can parse numbers
                if let recentLine = insight.evidence.first(where: { $0.lowercased().contains("recent avg") }),
                   let baselineLine = insight.evidence.first(where: { $0.lowercased().contains("baseline avg") }) {
                    let recent = Double(recentLine.components(separatedBy: CharacterSet(charactersIn: "0123456789.-").inverted).joined()) ?? 0
                    let base = Double(baselineLine.components(separatedBy: CharacterSet(charactersIn: "0123456789.-").inverted).joined()) ?? 0
                    let series = [base * 0.9, base, (base + recent) / 2, recent]
                    SparklineView(values: series, lineColor: recent >= base ? Color.mossInsight : Color.momentumAmber)
                        .frame(width: 60, height: 22)
                }
            }
            
            Spacer()
            
            // Category badge
            Text(categoryText(for: insight.category))
                .font(AppFonts.sans(9, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor(for: insight.category))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
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
        case .preference: return .nordicSlate
        case .health: return .mossInsight
        case .habit: return .midnightSpruce
        case .recommendation: return .momentumAmber
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

// Fallback Sparkline in case the component isn't linked in this target
struct SparklineView: View {
    let values: [Double]
    var lineColor: Color = .mossInsight
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let vals = values.filter { $0.isFinite }
            let minV = vals.min() ?? 0
            let maxV = vals.max() ?? 1
            let range = max(maxV - minV, 0.0001)
            let points: [CGPoint] = vals.enumerated().map { (i, v) in
                let x = CGFloat(i) / CGFloat(max(vals.count - 1, 1)) * w
                let y = h - CGFloat((v - minV) / range) * h
                return CGPoint(x: x, y: y)
            }
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for p in points.dropFirst() { path.addLine(to: p) }
            }
            .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
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
