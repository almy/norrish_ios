import SwiftUI
import UIKit

private enum OnboardingStep: Int, CaseIterable {
    case mission = 1
    case trends = 2
    case plateScan = 3
    case productScan = 4
    case profile = 5
    case ready = 6

    var index: Int { rawValue }
}

struct FirstTimeOnboardingView: View {
    let onComplete: () -> Void
    let onSnapMeal: () -> Void
    let onScanProduct: () -> Void

    @EnvironmentObject private var profileIdentity: ProfileIdentityStore
    @EnvironmentObject private var preferencesManager: DietaryPreferencesManager
    @State private var step: OnboardingStep = .mission
    @State private var nameDraft = ""
    @State private var exclusions: Set<String> = []
    @State private var needs: Set<String> = []
    @State private var focus: String = "Clean Eating"
    @State private var showingAvatarSourceDialog = false
    @State private var showingAvatarCamera = false
    @State private var showingAvatarLibrary = false
    @State private var showingPhotoPermissionAlert = false
    @State private var selectedAvatarImage: UIImage?

    var body: some View {
        ZStack {
            Color.nordicBone.ignoresSafeArea()

            Group {
                switch step {
                case .mission:
                    OnboardingMissionScreen(
                        currentStep: step.index,
                        totalSteps: OnboardingStep.allCases.count,
                        onNext: next
                    )
                case .trends:
                    OnboardingTrendsScreen(
                        currentStep: step.index,
                        totalSteps: OnboardingStep.allCases.count,
                        onNext: next,
                        onSkip: skipToProfile
                    )
                case .plateScan:
                    OnboardingPlateScanScreen(
                        currentStep: step.index,
                        totalSteps: OnboardingStep.allCases.count,
                        onBack: previous,
                        onNext: next,
                        onSkip: skipToProfile
                    )
                case .productScan:
                    OnboardingProductScanScreen(
                        currentStep: step.index,
                        totalSteps: OnboardingStep.allCases.count,
                        onBack: previous,
                        onNext: { step = .profile },
                        onSkip: skipToProfile
                    )
                case .profile:
                    OnboardingProfileScreen(
                        nameDraft: $nameDraft,
                        exclusions: $exclusions,
                        needs: $needs,
                        focus: $focus,
                        avatarImage: profileIdentity.avatarImage(),
                        currentStep: step.index,
                        totalSteps: OnboardingStep.allCases.count,
                        onBack: previous,
                        onAvatarTap: { showingAvatarSourceDialog = true },
                        onCompleteProfile: {
                            applyProfileStep()
                            applyTailorStep()
                            step = .ready
                        }
                    )
                case .ready:
                    OnboardingReadyScreen(
                        onSnapMeal: {
                            onComplete()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onSnapMeal()
                            }
                        },
                        onScanProduct: {
                            onComplete()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onScanProduct()
                            }
                        }
                    )
                }
            }
            .id(step.rawValue)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .animation(.easeInOut(duration: 0.32), value: step)
        }
        .onAppear {
            nameDraft = profileIdentity.displayName
        }
        .fullScreenCover(isPresented: $showingAvatarCamera) {
            CameraCaptureView(image: $selectedAvatarImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingAvatarLibrary) {
            PhotoLibraryPickerView(image: $selectedAvatarImage)
                .ignoresSafeArea()
        }
        .confirmationDialog("Edit Photo", isPresented: $showingAvatarSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showingAvatarCamera = true }
            }
            Button("Choose from Library") { requestPhotoLibraryAccessForAvatar() }
            if PhotoLibraryPermission.canManageLimitedSelection {
                Button("Manage Selected Photos") {
                    PhotoLibraryPermission.presentLimitedLibraryPicker()
                }
            }
            if profileIdentity.avatarImage() != nil {
                Button("Remove Photo", role: .destructive) {
                    profileIdentity.removeAvatar()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Photo Access Needed", isPresented: $showingPhotoPermissionAlert) {
            Button("Open Settings") {
                PhotoLibraryPermission.openSettings()
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Allow Photos access to choose an avatar. You can grant Full Access or select Limited Photos.")
        }
        .onChange(of: selectedAvatarImage) { _, newValue in
            guard let image = newValue else { return }
            profileIdentity.updateAvatar(image)
            selectedAvatarImage = nil
        }
    }

    private func next() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    private func previous() {
        guard let prev = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    private func skipToProfile() {
        step = .profile
    }

    private func applyProfileStep() {
        profileIdentity.updateDisplayName(nameDraft)
        setAllergy(.peanuts, enabled: exclusions.contains("No Peanuts"))
        setRestriction(.lowSodium, enabled: exclusions.contains("Low Sodium"))
        setRestriction(.glutenFree, enabled: exclusions.contains("Gluten Free"))
        setRestriction(.dairyfree, enabled: exclusions.contains("Dairy Free"))
        setCustomRestriction("No Added Sugar", enabled: exclusions.contains("No Added Sugar"))
    }

    private func applyTailorStep() {
        setRestriction(.dairyfree, enabled: needs.contains("Dairy Free"))
        setRestriction(.glutenFree, enabled: needs.contains("Gluten Free"))
        setRestriction(.vegan, enabled: needs.contains("Plant Based"))
        setRestriction(.vegetarian, enabled: needs.contains("Vegetarian"))
        setRestriction(.pescatarian, enabled: needs.contains("Pescatarian"))
        setRestriction(.paleo, enabled: needs.contains("Paleo"))
        setRestriction(.keto, enabled: needs.contains("Keto"))
        setRestriction(.lowCarb, enabled: needs.contains("Low Carb"))
        setRestriction(.halal, enabled: needs.contains("Halal"))
        setRestriction(.kosher, enabled: needs.contains("Kosher"))
        UserDefaults.standard.set(focus, forKey: "profile.primaryFocus")
    }

    private func setRestriction(_ restriction: DietaryRestriction, enabled: Bool) {
        if enabled {
            if !preferencesManager.selectedDietaryRestrictions.contains(restriction) {
                preferencesManager.toggleDietaryRestriction(restriction)
            }
        } else if preferencesManager.selectedDietaryRestrictions.contains(restriction) {
            preferencesManager.toggleDietaryRestriction(restriction)
        }
    }

    private func setAllergy(_ allergy: Allergy, enabled: Bool) {
        if enabled {
            if !preferencesManager.selectedAllergies.contains(allergy) {
                preferencesManager.toggleAllergy(allergy)
            }
        } else if preferencesManager.selectedAllergies.contains(allergy) {
            preferencesManager.toggleAllergy(allergy)
        }
    }

    private func setCustomRestriction(_ value: String, enabled: Bool) {
        if enabled {
            if !preferencesManager.customRestrictions.contains(value) {
                preferencesManager.addCustomRestriction(value)
            }
        } else if preferencesManager.customRestrictions.contains(value) {
            preferencesManager.removeCustomRestriction(value)
        }
    }

    private func requestPhotoLibraryAccessForAvatar() {
        Task {
            let status = await PhotoLibraryPermission.requestReadWriteAccess()
            await MainActor.run {
                if PhotoLibraryPermission.hasAccess(status) {
                    showingAvatarLibrary = true
                } else {
                    showingPhotoPermissionAlert = true
                }
            }
        }
    }
}

#Preview {
    FirstTimeOnboardingView(onComplete: {}, onSnapMeal: {}, onScanProduct: {})
        .environmentObject(ProfileIdentityStore.shared)
        .environmentObject(DietaryPreferencesManager.shared)
}
