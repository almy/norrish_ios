# Norrish iOS App - UX Research Analysis

**Document Version:** 1.0
**Date:** January 2026
**Analyst:** UX Research Review

---

## Executive Summary

Norrish is a health and nutrition tracking iOS app that enables users to scan product barcodes and analyze meals through AI-powered plate photography. This UX research analysis examines the user interface, interaction patterns, value proposition, and user experience across all screens and flows. The app demonstrates solid foundational UX patterns but has several opportunities for improvement in accessibility, onboarding, error handling, and user feedback mechanisms.

---

## Table of Contents

1. [App Overview & Value Proposition](#1-app-overview--value-proposition)
2. [Information Architecture](#2-information-architecture)
3. [User Flow Analysis](#3-user-flow-analysis)
4. [Screen-by-Screen UX Evaluation](#4-screen-by-screen-ux-evaluation)
5. [Interaction Patterns](#5-interaction-patterns)
6. [Data Capture & Value Delivery](#6-data-capture--value-delivery)
7. [Accessibility Audit](#7-accessibility-audit)
8. [Localization & Internationalization](#8-localization--internationalization)
9. [Error Handling & Edge Cases](#9-error-handling--edge-cases)
10. [UX Strengths](#10-ux-strengths)
11. [UX Issues & Recommendations](#11-ux-issues--recommendations)
12. [Competitive UX Benchmark](#12-competitive-ux-benchmark)
13. [Conclusion & Priority Matrix](#13-conclusion--priority-matrix)

---

## 1. App Overview & Value Proposition

### 1.1 Core Value Proposition
Norrish helps users make healthier food choices by providing:
- **Instant nutritional information** via barcode scanning
- **AI-powered meal analysis** via plate photography
- **Nutri-Score ratings** (A-E grade system) for quick health assessment
- **Personalized insights** based on dietary preferences and eating patterns
- **Privacy-first approach** with local-only data storage

### 1.2 Target Users
- Health-conscious individuals tracking nutrition
- Users with dietary restrictions or allergies
- People seeking to understand their eating habits
- Those interested in the Nutri-Score rating system

### 1.3 Value Delivery Assessment

| Feature | Value Delivered | User Effort Required |
|---------|-----------------|---------------------|
| Barcode Scanning | High - instant nutrition data | Low - single tap |
| Plate Analysis | High - comprehensive meal breakdown | Medium - photo + region selection |
| History Tracking | Medium - review past scans | Low - passive collection |
| Dietary Preferences | High - personalized warnings | Medium - initial setup |
| Insights Dashboard | Medium - pattern recognition | Low - automatic generation |

**Assessment:** The app delivers high value for low-to-medium user effort, which is optimal for retention.

---

## 2. Information Architecture

### 2.1 Navigation Structure

```
Tab Bar (4 tabs)
├── Scan (Tab 0)
│   ├── Dashboard Insights Carousel
│   ├── Start Scanning Button → Camera View
│   ├── Recent Scans List
│   └── Product Detail Sheet
│
├── Plate (Tab 1)
│   ├── Camera Preview Area
│   ├── Take Photo / Choose Photo
│   ├── Food Region Selection View
│   ├── Analysis Results Sheet
│   └── Plate Detail View
│
├── History (Tab 2)
│   ├── Search Bar
│   ├── Nutri-Score Filter (A-E)
│   ├── Type Filter (All/Products/Plates)
│   ├── Sort Options (Date/Nutri-Score)
│   └── Combined History List
│
└── Profile (Tab 3)
    ├── User Info Header
    ├── Dietary Preferences Summary
    ├── Notification Settings
    ├── Privacy & Account
    └── Logout
```

### 2.2 IA Evaluation

**Strengths:**
- Flat navigation hierarchy (max 2 levels deep)
- Clear tab differentiation with distinct icons
- Logical grouping of related features

**Issues:**
- History combines two different item types (products + plates) which may cause confusion
- No dedicated "Learn" or "Education" section for understanding Nutri-Score
- Settings icon on Scan tab does nothing (dead button)

### 2.3 Content Hierarchy

The app follows a consistent content hierarchy pattern:
1. **Primary action** (prominent button)
2. **Supporting content** (images, summaries)
3. **Detailed information** (expandable sections)
4. **Tertiary actions** (feedback, sharing)

---

## 3. User Flow Analysis

### 3.1 Barcode Scanning Flow

```
[Scan Tab] → [Tap "Start Scanning"] → [Camera Opens] → [Barcode Detected]
    → [Loading Overlay] → [Product Detail Sheet] → [View Nutrition] → [Close]
```

**Flow Duration:** ~3-8 seconds (scan to results)

**UX Observations:**
- Immediate feedback when barcode detected
- Loading state is visible and informative ("Fetching product information...")
- Product detail sheet uses drag-to-dismiss pattern
- Clear back navigation with chevron icon

**Issues Identified:**
- No haptic feedback on successful scan
- No guidance for unrecognized barcodes
- Camera doesn't remember torch state between sessions

### 3.2 Plate Analysis Flow

```
[Plate Tab] → [Take Photo/Choose Photo] → [Food Region Selection]
    → [Adjust Regions] → [Analyze] → [Results View] → [View Details/New Scan]
```

**Flow Duration:** ~15-30 seconds (photo to results)

**UX Observations:**
- Two clear entry points (camera vs. library)
- Region selection allows manual adjustment (advanced UX)
- Progress indication during analysis
- Option to reopen previous analysis

**Issues Identified:**
- Region selection UI is complex for casual users
- No preview of what the region selection overlay represents
- "Confidence" value shown but not explained
- No undo for region adjustments

### 3.3 History Review Flow

```
[History Tab] → [Search/Filter] → [Tap Item] → [Detail Sheet] → [Close]
```

**Flow Duration:** ~2-5 seconds

**UX Observations:**
- Swipe-to-delete pattern implemented
- Filter chips provide quick filtering
- Sort options are accessible

**Issues Identified:**
- No bulk delete option
- No export functionality
- Search only filters by name, not by date or score

### 3.4 Profile Setup Flow

```
[Profile Tab] → [Edit Preferences] → [Select Allergies] → [Select Restrictions]
    → [Add Custom] → [Save]
```

**Flow Duration:** ~30-60 seconds (first-time setup)

**UX Observations:**
- Progress indicator shows completion percentage
- Pill-style selection is visually clear
- Custom allergies/restrictions supported

**Issues Identified:**
- No onboarding prompts new users to set preferences
- Profile completion percentage doesn't link to specific missing items
- No explanation of why preferences matter

---

## 4. Screen-by-Screen UX Evaluation

### 4.1 Scan Tab (BarcodeScannerView)

| Element | Evaluation | Rating |
|---------|------------|--------|
| Header | Clean, bold typography | Good |
| Scan Area | Large, clear visual affordance | Good |
| CTA Button | High contrast green, clear label | Excellent |
| Insights Carousel | Auto-rotating, swipeable | Good |
| Recent Scans | Thumbnail + info layout | Good |
| Empty State | Icon + text guidance | Good |
| Settings Button | Non-functional | Poor |

**Recommendations:**
- Add functionality to settings button or remove it
- Add haptic feedback on successful scan
- Consider adding manual barcode entry option

### 4.2 Plate Analysis Tab (PlateAnalysisView)

| Element | Evaluation | Rating |
|---------|------------|--------|
| Header | Friendly copy ("What's on your plate?") | Excellent |
| Preview Area | Clear placeholder with icon | Good |
| Photo Actions | Two distinct buttons | Good |
| Pro Tip | Helpful guidance | Good |
| Previous Analysis | Convenient recovery option | Excellent |
| Loading State | Progress indicator present | Good |

**Recommendations:**
- Add example images showing what works well
- Explain the region selection before showing it
- Add cancel option during analysis

### 4.3 Food Region Selection (FoodRegionSelectionView)

| Element | Evaluation | Rating |
|---------|------------|--------|
| Instruction | Brief but clear | Fair |
| Region Overlays | Color-coded, draggable | Good |
| Confidence Display | Technical metric exposed | Poor |
| Resize Controls | +/- buttons | Fair |
| Include Toggle | Per-region selection | Good |
| Analyze Button | Disabled when nothing selected | Good |

**Recommendations:**
- Provide tooltip explaining what regions represent
- Hide confidence from casual users (show on demand)
- Add "Select All" / "Clear All" buttons
- Provide visual feedback for drag operations
- Add pinch-to-resize gesture support

### 4.4 Plate Analysis Results (PlateAnalysisResultView)

| Element | Evaluation | Rating |
|---------|------------|--------|
| Header Card | Beautiful gradient overlay | Excellent |
| Score Display | Large, prominent grade letter | Excellent |
| Macronutrient Dots | Compact, color-coded | Good |
| Micronutrients Grid | Clean card layout | Good |
| Ingredients List | Simple rows | Good |
| Insights Cards | Color-coded by type | Excellent |
| Feedback Section | Thumbs up/down | Good |
| New Scan CTA | Prominent green button | Good |

**Recommendations:**
- Add sharing functionality for results
- Allow editing/correcting ingredients
- Show comparison to dietary goals
- Add more detailed micronutrient information

### 4.5 Product Detail (ProductDetailView)

| Element | Evaluation | Rating |
|---------|------------|--------|
| Back Navigation | Chevron icon, consistent | Good |
| Product Image | Cached, with fallback | Good |
| Nutri-Score Badge | Tappable for info | Excellent |
| Nutrition Grid | 2-column card layout | Good |
| Personalized Insights | Contextual recommendations | Good |

**Recommendations:**
- Add ingredients list view
- Show allergen warnings prominently
- Add product comparison feature
- Enable adding to favorites

### 4.6 History Tab (ContentView - History)

| Element | Evaluation | Rating |
|---------|------------|--------|
| Search Bar | Standard pattern | Good |
| Filter Chips | Scrollable, clear selection | Good |
| Type Segmented Control | Clear labels | Good |
| Sort Segmented Control | Date/Nutri-Score | Good |
| List Items | Consistent row design | Good |
| Empty State | Helpful guidance | Good |
| Swipe-to-Delete | Standard iOS pattern | Good |

**Recommendations:**
- Add date range filter
- Show aggregate statistics (weekly averages)
- Add bulk actions
- Implement pull-to-refresh

### 4.7 Profile Tab (ProfileView)

| Element | Evaluation | Rating |
|---------|------------|--------|
| Avatar | Placeholder image | Fair |
| Name Display | Hardcoded "Sophia Bennett" | Poor |
| Membership Badge | Non-functional | Poor |
| Dietary Pills | Scrollable, color-coded | Good |
| Toggle Rows | Standard iOS pattern | Good |
| Logout Button | Clear destructive styling | Good |

**Recommendations:**
- Allow actual profile customization
- Remove hardcoded dummy data
- Add profile photo upload
- Show actual membership/plan status

### 4.8 Dietary Preferences (DietaryPreferencesView)

| Element | Evaluation | Rating |
|---------|------------|--------|
| Progress Bar | Visual completion indicator | Good |
| Section Headers | Clear descriptions | Good |
| Allergy Pills | Toggle with +/x icons | Good |
| Custom Entry | Sheet-based input | Good |
| Save Button | Full-width CTA | Good |

**Recommendations:**
- Add search for common allergies
- Show impact preview ("This will hide X products")
- Add severity levels for allergies

---

## 5. Interaction Patterns

### 5.1 Gesture Support

| Gesture | Usage | Implementation |
|---------|-------|----------------|
| Tap | Primary selection | Universal |
| Swipe Left | Delete items | History list |
| Drag | Move regions | Region selection |
| Pull-down | Dismiss sheets | Sheet views |
| Scroll | Navigate content | All scrollable views |
| Long-press | Not implemented | N/A |
| Pinch | Not implemented | N/A |

**Gap:** No long-press context menus or pinch gestures

### 5.2 Feedback Mechanisms

| Feedback Type | Implementation | Quality |
|---------------|----------------|---------|
| Visual | Loading indicators, state changes | Good |
| Haptic | Not implemented | Missing |
| Audio | Not implemented | Missing |
| Text | Error messages, success states | Fair |

### 5.3 Animation & Transitions

- Sheet presentations use standard iOS springs
- Tab switches are instant (no custom animation)
- Carousel auto-rotates with implicit animation
- Button states have standard opacity changes

**Assessment:** Animations are functional but not distinctive. No brand-specific motion design.

---

## 6. Data Capture & Value Delivery

### 6.1 Data Captured from Users

| Data Point | When Captured | How Used |
|------------|---------------|----------|
| Barcode scans | Scan tab | History, insights |
| Plate photos | Plate tab | Analysis, history |
| Food regions | Region selection | Analysis accuracy |
| Allergies | Profile setup | Warnings, filtering |
| Dietary restrictions | Profile setup | Recommendations |
| Feedback (thumbs) | After analysis | AI improvement |
| Language preference | Settings | UI localization |
| Theme preference | Settings | UI appearance |

### 6.2 Value Delivered Back to Users

| Data Input | Value Output |
|------------|--------------|
| Barcode | Full nutrition breakdown, Nutri-Score |
| Plate photo | Meal analysis, calorie estimate, suggestions |
| Allergies | Warning alerts, safe recommendations |
| Dietary restrictions | Personalized insights |
| Scan history | Pattern recognition, weekly trends |

### 6.3 Data Privacy Assessment

**Strengths:**
- All data stored locally (SwiftData)
- Clear privacy policy view
- No cloud sync requirement
- Only barcode/image sent to backend for analysis

**Concerns:**
- No data export option
- No account deletion flow
- Backend receives plate images (privacy implication)

---

## 7. Accessibility Audit

### 7.1 Current State

**Critical Finding:** No accessibility markup found in the codebase.

| Accessibility Feature | Status |
|-----------------------|--------|
| VoiceOver labels | Not implemented |
| Accessibility hints | Not implemented |
| Dynamic Type | Partial (some hardcoded sizes) |
| Color contrast | Generally good |
| Reduced motion | Not checked |
| Button minimum size | Most comply (44pt) |

### 7.2 Specific Issues

1. **Images without alt text**
   - Product images lack accessibility labels
   - Nutri-Score badges not labeled for screen readers
   - Chart/graph data not exposed

2. **Interactive elements**
   - Region overlays not accessible
   - Carousel auto-rotation may confuse VoiceOver
   - Custom buttons lack accessibility traits

3. **Color reliance**
   - Nutri-Score colors (A=green, E=red) need text alternatives
   - Insight cards rely on color coding

### 7.3 Recommendations (Priority: HIGH)

```swift
// Example: Add to NutriScoreBadge
.accessibilityLabel("Nutri-Score \(letter.rawValue), \(letter.description)")
.accessibilityHint("Tap for more information about this nutrition grade")

// Example: Add to ProductDetailView images
.accessibilityLabel(product.name)
.accessibilityAddTraits(.isImage)
```

---

## 8. Localization & Internationalization

### 8.1 Current Support

| Language | Status | Completeness |
|----------|--------|--------------|
| English | Primary | ~95% |
| Swedish | Secondary | ~95% |

### 8.2 Localization Quality

**Strengths:**
- Comprehensive string coverage
- Context comments in strings files
- Language picker in settings
- Manager pattern for runtime switching

**Issues:**
- Some hardcoded English strings found:
  - "Scan" header in BarcodeScannerView
  - "Pro tip" in PlateAnalysisView
  - "Previous Analysis" in PlateAnalysisView
  - Section titles in NutriScoreInfoView
  - Profile name "Sophia Bennett"
- Number formatting not localized
- Date formatting uses device locale (good)

### 8.3 Recommendations

1. Audit all views for hardcoded strings
2. Add RTL (right-to-left) support foundation
3. Use `NumberFormatter` for all numeric displays
4. Consider adding more languages (German, French, Spanish)

---

## 9. Error Handling & Edge Cases

### 9.1 Error States Identified

| Scenario | Current Handling | Quality |
|----------|------------------|---------|
| Barcode not found | Alert with "OK" button | Fair |
| Network failure | Generic error alert | Poor |
| Camera unavailable | Button disabled | Good |
| Empty history | Helpful empty state | Good |
| Analysis failure | Error message displayed | Fair |
| Invalid image | No specific handling | Poor |

### 9.2 Edge Cases Not Handled

1. **No internet connection**
   - No offline mode
   - No cached product database
   - No retry mechanism visible to users

2. **Camera permissions denied**
   - Button disabled but no explanation
   - No deep link to Settings

3. **Storage full**
   - No handling for SwiftData write failures
   - Images could fail to cache

4. **Timeout scenarios**
   - Analysis can take long
   - No timeout feedback to users

### 9.3 Recommendations

```swift
// Example: Better error handling
struct NetworkErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
            Text("No Internet Connection")
            Text("Please check your connection and try again")
            Button("Retry") { /* retry action */ }
        }
    }
}
```

---

## 10. UX Strengths

### 10.1 What Works Well

1. **Clear Value Proposition**
   - Users immediately understand what each tab does
   - Core scanning functionality is prominent

2. **Visual Design**
   - Consistent color system (mint as primary)
   - Good use of whitespace
   - Card-based layout is clean and modern

3. **Progressive Disclosure**
   - Basic info shown first
   - Details available on tap
   - Complex features (region selection) are optional

4. **Feedback Collection**
   - Thumbs up/down after analysis
   - Clear explanation of why feedback helps

5. **Privacy-First Approach**
   - Local storage emphasized
   - Privacy policy accessible
   - No account required

6. **Personalization**
   - Dietary preferences affect recommendations
   - Dashboard insights are contextual

7. **Multi-Language Support**
   - Runtime language switching
   - Good localization coverage

8. **Recovery Options**
   - "Reopen Previous Analysis" feature
   - History preserves all scans

### 10.2 Standout Features

- **Nutri-Score Info View**: Educational content explaining the scoring system
- **Region Selection**: Advanced feature for power users
- **Personalized Insights Carousel**: Contextual recommendations based on history
- **Combined History**: Products and plates in one timeline

---

## 11. UX Issues & Recommendations

### 11.1 Critical Issues

| Issue | Impact | Recommendation |
|-------|--------|----------------|
| No accessibility support | Excludes disabled users | Add VoiceOver labels to all interactive elements |
| Non-functional settings button | Broken expectation | Remove or implement |
| Hardcoded profile data | Feels like demo app | Allow actual profile editing |
| No onboarding | New users don't set preferences | Add first-launch onboarding flow |

### 11.2 High Priority Issues

| Issue | Impact | Recommendation |
|-------|--------|----------------|
| No haptic feedback | Reduced delight | Add haptics for scans, saves, errors |
| Poor error messages | User confusion | Create specific error states with actions |
| Region selection complexity | User confusion | Add tutorial tooltip or simpler mode |
| No offline support | Broken experience | Cache common products locally |
| Hardcoded English strings | Inconsistent localization | Complete string externalization |

### 11.3 Medium Priority Issues

| Issue | Impact | Recommendation |
|-------|--------|----------------|
| No data export | User control | Add export to CSV/JSON |
| No sharing | Reduced engagement | Add share sheet for results |
| No search by date | Limited filtering | Expand search capabilities |
| No bulk delete | Tedious cleanup | Add selection mode |
| No favorites | Missing convenience | Add favorite products/meals |

### 11.4 Low Priority Issues

| Issue | Impact | Recommendation |
|-------|--------|----------------|
| No dark mode preview | Minor inconvenience | Add preview in theme selector |
| No animation refinements | Polish | Add custom transitions |
| No dietary goal tracking | Missing feature | Add daily/weekly targets |
| No widget support | Convenience | Add iOS widgets |

---

## 12. Competitive UX Benchmark

### 12.1 Comparison with Similar Apps

| Feature | Norrish | MyFitnessPal | Yuka | Lifesum |
|---------|---------|--------------|------|---------|
| Barcode scanning | Yes | Yes | Yes | Yes |
| Photo analysis | Yes | Manual entry | No | Manual entry |
| Nutri-Score | Yes | No | Yes | No |
| Offline mode | No | Partial | Yes | Partial |
| Accessibility | No | Yes | Partial | Yes |
| Social features | No | Yes | No | No |
| Free tier | Yes | Yes (limited) | Yes | Yes (limited) |

### 12.2 UX Differentiators

**Norrish advantages:**
- Combined barcode + plate analysis in one app
- Region-based food detection (unique)
- Privacy-first (no account required)
- Clean, modern UI

**Competitors' advantages:**
- Better offline support
- More established databases
- Social/sharing features
- Goal tracking and planning

---

## 13. Conclusion & Priority Matrix

### 13.1 Overall UX Assessment

**Score: 7.2/10**

The Norrish app provides a solid foundation for nutrition tracking with a clean interface and clear value proposition. The dual scanning approach (barcode + plate) is a differentiator. However, significant gaps in accessibility, onboarding, and error handling prevent it from reaching its full potential.

### 13.2 Priority Matrix

```
                    HIGH IMPACT
                        │
   ┌────────────────────┼────────────────────┐
   │ • Accessibility    │ • Onboarding flow  │
   │ • Fix dead buttons │ • Haptic feedback  │
   │                    │ • Better errors    │
   │    QUICK WINS      │   STRATEGIC        │
LOW├────────────────────┼────────────────────┤HIGH
EFF│                    │                    │EFF
ORT│ • Remove hardcoded │ • Offline mode     │ORT
   │   strings          │ • Data export      │
   │ • Animation polish │ • Widget support   │
   │                    │                    │
   │    FILL-INS        │   BIG BETS         │
   └────────────────────┼────────────────────┘
                        │
                    LOW IMPACT
```

### 13.3 Recommended Roadmap

**Phase 1: Foundation (1-2 weeks)**
- Add VoiceOver labels to all screens
- Fix/remove non-functional settings button
- Complete string localization
- Add haptic feedback

**Phase 2: Onboarding (2-3 weeks)**
- Create first-launch onboarding flow
- Add profile customization
- Implement preference impact preview

**Phase 3: Polish (2-3 weeks)**
- Improve error handling with specific states
- Add sharing functionality
- Implement search improvements
- Add data export

**Phase 4: Features (4+ weeks)**
- Offline mode with cached products
- iOS widgets
- Goal tracking
- Social/comparison features

---

## Appendix A: View Component Inventory

| Component | File | Reusability |
|-----------|------|-------------|
| NutriScoreBadge | Views/Components/ | High |
| FilterButton | ContentView.swift | Medium |
| DietaryPill | ProfileView.swift | High |
| AllergyPill | DietaryPreferencesView.swift | High |
| NutritionCard | ProductDetailView.swift | High |
| MicronutrientCard | PlateDetailView.swift | High |
| ModernInsightCard | PlateDetailView.swift | High |
| CachedAsyncImage | Views/Components/ | High |
| PersonalizedInsightCarousel | Views/Components/ | Medium |

## Appendix B: Localization Keys Needing Addition

```
// BarcodeScannerView
"scan.header" = "Scan";

// PlateAnalysisView
"plate.pro_tip" = "Pro tip";
"plate.previous_analysis" = "Previous Analysis";
"plate.reopen_results" = "Reopen Results";

// FoodRegionSelectionView
"regions.select_title" = "Select food areas";
"regions.include" = "Include";
"regions.confidence" = "conf: %.2f";
"regions.cancel" = "Cancel";
"regions.analyze" = "Analyze";

// NutriScoreInfoView
"nutriscore.what_is" = "What is Nutri-Score?";
"nutriscore.this_product" = "This Product";
"nutriscore.this_plate" = "This Plate";
"nutriscore.how_computed" = "How the score is computed";
"nutriscore.categories" = "Category specifics";
"nutriscore.references" = "References";
```

---

**Document prepared by UX Research**
**Next review date:** Q2 2026
