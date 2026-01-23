# Claude Code Instructions for healthScanner Repository

This document contains mandatory instructions that must be followed every time code is generated, modified, or added to this repository.

## 📱 1. LOCALIZATION - HIGHEST PRIORITY

### Static Text Requirements
- **NEVER** use hardcoded strings in any UI component
- **ALWAYS** use the localization system for any user-facing text
- **ALL** static text must support the configured languages: English (en) and Swedish (sv)

### Implementation Steps for Every Text String

1. **Add to Localizable.strings files:**
   ```
   // English: /healthScanner/Resources/Localization/en.lproj/Localizable.strings
   "key.name" = "English Text";

   // Swedish: /healthScanner/Resources/Localization/sv.lproj/Localizable.strings
   "key.name" = "Swedish Text";
   ```

2. **Use in SwiftUI views:**
   ```swift
   Text("key.name".localized)
   // OR
   Text(NSLocalizedString("key.name", comment: "Description"))
   ```

3. **Use in code/alerts:**
   ```swift
   let message = "key.name".localized
   ```

### Localization Key Naming Convention
```
category.component.purpose
```

Examples:
- `button.camera.take_photo` = "Take Photo" / "Ta foto"
- `alert.error.network` = "Network Error" / "Nätverksfel"
- `label.nutrition.calories` = "Calories" / "Kalorier"
- `title.analysis.results` = "Analysis Results" / "Analysresultat"
- `tip.camera.lighting` = "For best results, ensure good lighting" / "För bästa resultat, se till att det finns bra ljus"

### Required Languages
- **English (en)** - Primary language
- **Swedish (sv)** - Secondary language

### Before Submitting Code
1. ✅ All static strings have localization keys
2. ✅ Keys added to both en.lproj and sv.lproj files
3. ✅ Swedish translations are accurate and natural
4. ✅ No hardcoded strings remain in the code

---

## 🏗️ 2. ARCHITECTURE PATTERNS

### Model Structure
- Use separate model files in `/Models/` directory
- Implement `Codable` for all data models
- Use `@Model` for SwiftData entities
- Follow existing naming patterns (e.g., `PlateAnalysis`, `PlateAnalysisHistory`)

### ViewModels
- Use `@MainActor` for UI-related ViewModels
- Implement `ObservableObject` protocol
- Place in `/ViewModels/` directory
- Use `@Published` for state that affects UI

### Views
- Keep views focused and small
- Extract subviews using private extensions
- Use consistent spacing and padding (multiples of 4/8)
- Follow existing color schemes and design patterns

---

## 🎨 3. UI/UX STANDARDS

### Design System
- **Primary Colors:** Mint, Green gradients
- **Secondary Colors:** Orange, Blue accents
- **Spacing:** 8, 12, 16, 20, 24, 28px increments
- **Corner Radius:** 12, 16, 20, 24px standard values
- **Font Weights:** Use `.semibold` for headings, `.headline` for buttons

### Component Patterns
```swift
// Button Style Example
Button("action.take_photo".localized) {
    // action
}
.font(.headline)
.foregroundColor(.white)
.frame(maxWidth: .infinity)
.padding(.vertical, 16)
.background(LinearGradient(colors: [.mint, .green], startPoint: .leading, endPoint: .trailing))
.cornerRadius(24)
```

### Navigation
- Use `NavigationView` for main containers
- Use `.sheet()` for modal presentations
- Use `.fullScreenCover()` for camera/immersive experiences

---

## 📊 4. DATA HANDLING

### SwiftData Integration
- Use `@Environment(\.modelContext)` for data operations
- Implement proper error handling for data operations
- Use `@Query` for data fetching in views
- Follow existing patterns in `PlateAnalysisHistory`

### API Integration
- Use async/await for network calls
- Implement proper error handling with localized messages
- Follow existing `OpenAIService` patterns
- Use structured responses when possible

---

## 🔧 5. CODE QUALITY

### Error Handling
```swift
do {
    // operation
} catch {
    let message = "error.operation_failed".localized
    // Handle with localized error message
}
```

### Logging - MANDATORY FOR ALL CODE
- **ALWAYS** add extensive but smart logging to new code
- **INCLUDE** context, parameters, and state information in log messages
- **USE** emoji prefixes for better readability and categorization:
  - 🔵 `.info` - General information and flow tracking
  - 🟢 `.success` - Successful operations and completions
  - 🔴 `.error` - Errors and failures
  - ⚠️ `.warning` - Warnings and potential issues
  - 🔄 `.debug` - Detailed debugging information
  - 📊 `.data` - Data processing and transformations
  - 🚀 `.start` - Method/operation start
  - ✅ `.complete` - Method/operation completion

#### Logging Examples
```swift
// Method entry with parameters
print("🚀 [ServiceName] Starting operation: methodName(param1: \(param1), param2: \(param2))")

// Success with results
print("✅ [ServiceName] Operation completed successfully. Result: \(result)")

// Error with context
print("🔴 [ServiceName] Operation failed: \(error.localizedDescription). Context: \(context)")

// State changes
print("📊 [ServiceName] State changed from \(oldState) to \(newState)")

// Data processing
print("📊 [ServiceName] Processing \(items.count) items")

// Warning conditions
print("⚠️ [ServiceName] Potential issue detected: \(issue). Continuing with fallback.")
```

### Comments - MANDATORY FOR ALL CODE
- **ALWAYS** add extensive but smart comments that explain WHAT the code is doing and WHY
- **EXPLAIN** the business logic, not just the syntax
- **DOCUMENT** complex algorithms, business rules, and non-obvious decisions
- **USE** proper comment structure and organization

#### Comment Guidelines
```swift
/// High-level class/method documentation
/// - Parameter param: Description of what this parameter represents
/// - Returns: Description of what is returned
/// - Note: Important usage notes or limitations

// MARK: - Section Organization
// Use MARK comments to organize code into logical sections

// Business Logic Comments - Explain WHY, not WHAT
// This validation ensures user privacy by checking consent before processing personal data
// The timeout is set to 30 seconds to balance user experience with server load

// Complex Algorithm Comments
// Implementation of custom food recognition algorithm:
// 1. Pre-process image to normalize lighting conditions
// 2. Apply segmentation to isolate food regions
// 3. Run classification on each detected region
// 4. Combine results using confidence weighting

// State Management Comments
// Track loading states to prevent concurrent API calls and show proper UI feedback
// isLoading prevents duplicate requests while showError handles user communication

// Performance Comments
// Cache results for 5 minutes to reduce API calls and improve response time
// Use background queue for heavy processing to keep UI responsive
```

#### Required Comment Types
1. **File Headers** - Purpose and responsibility of the file
2. **Class/Struct Documentation** - What the type represents and its role
3. **Method Documentation** - Parameters, return values, side effects
4. **Business Logic** - Why decisions are made, not just what happens
5. **Complex Calculations** - Step-by-step explanation of algorithms
6. **State Changes** - Why and when state transitions occur
7. **Error Handling** - What errors are expected and how they're handled
8. **Performance Considerations** - Why certain optimizations are used

---

## 📱 6. PLATFORM CONSIDERATIONS

### iOS Specific
- Use `.padding(.horizontal, 20)` for consistent margins
- Implement proper safe area handling
- Use appropriate modal presentation styles
- Follow Human Interface Guidelines

### Accessibility
- Add proper accessibility labels
- Use semantic colors
- Ensure proper contrast ratios
- Test with VoiceOver

---

## 🔄 7. TESTING & VALIDATION

### Before Code Submission
1. ✅ Build succeeds without warnings
2. ✅ All strings are localized
3. ✅ UI components render correctly
4. ✅ Navigation flows work properly
5. ✅ Error states are handled gracefully

### Preview Requirements
- Include `#Preview` for all new SwiftUI views
- Use mock data that demonstrates functionality
- Test both light and dark modes when applicable

---

## 📂 8. FILE ORGANIZATION

### Directory Structure
```
/healthScanner/
├── Models/           # Data models
├── ViewModels/       # Business logic
├── Views/           # UI components
│   ├── Components/  # Reusable UI elements
│   └── ...
├── Services/        # API and business services
├── Resources/       # Assets and localization
│   └── Localization/
│       ├── en.lproj/
│       └── sv.lproj/
└── Extensions/      # Swift extensions
```

### Naming Conventions
- **Files:** PascalCase (e.g., `PlateAnalysisView.swift`)
- **Classes/Structs:** PascalCase (e.g., `PlateAnalysis`)
- **Variables/Functions:** camelCase (e.g., `analysisResult`)
- **Constants:** camelCase (e.g., `defaultTimeout`)

---

## ⚠️ 9. SECURITY & PRIVACY

### API Keys
- Never hardcode API keys
- Use environment variables or secure storage
- Follow existing patterns in `OpenAIService`

### User Data
- Handle camera permissions properly
- Respect user privacy choices
- Implement proper data retention policies

---

## 🔄 10. MAINTENANCE

### Code Reviews
- Follow all instructions before submitting
- Test localization in both languages
- Verify consistent design patterns
- Check for proper error handling

### Updates
- Keep dependencies updated
- Follow Swift and iOS best practices
- Maintain backward compatibility when possible

---

## 📞 QUICK REFERENCE

### Most Common Tasks

**Adding a new UI string:**
1. Add key to both `en.lproj/Localizable.strings` and `sv.lproj/Localizable.strings`
2. Use `"key".localized` in SwiftUI
3. Test in both languages

**Creating a new view:**
1. Place in appropriate `/Views/` subdirectory
2. Use existing design patterns
3. Localize all text
4. Add `#Preview`
5. Follow spacing/color guidelines

**Adding new model:**
1. Place in `/Models/` directory
2. Implement `Codable`
3. Add to SwiftData if persistent
4. Follow existing naming patterns

---

Remember: **Localization is mandatory for ALL user-facing text. No exceptions.**