# CLAUDE.md

Norrish is a health/nutrition scanner iOS app. **No external dependencies** (no SPM, CocoaPods, or Carthage) — pure native iOS.

- Bundle ID: `com.myftiu.ios.norrish` | Swift 5.10 | Deployment target: iOS 17.5

## Build & Test

```bash
# Build for simulator
xcodebuild -project healthScanner.xcodeproj -scheme healthScanner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild test -project healthScanner.xcodeproj -scheme healthScanner -testPlan healthScanner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class
xcodebuild test -project healthScanner.xcodeproj -scheme healthScanner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:healthScannerTests/BackendIntegrationTests

# Run API guardrails check
bash scripts/ios_api_guardrails.sh
```

Prefer running single test classes over the full suite for speed.

## Architecture

Read `agent_docs/architecture.md` when making structural decisions or touching data flow.

Key rule: `BackendAPIClient` is the only network client. `NutritionRecommendationEngine` is on-device only — never send raw nutrition data to the backend.

## Simulator & Fixtures

Read `agent_docs/simulator.md` when working on camera, AR, or ML features in the simulator.

## Code Style

Read `agent_docs/code-style.md` when writing new UI, strings, or commits.
