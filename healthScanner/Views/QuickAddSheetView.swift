import SwiftUI
import UIKit

struct QuickAddSheetView: View {
    let onScanBarcode: () -> Void
    let onScanPlate: () -> Void
    let onUploadPlate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("home.section.suggestions", comment: "Quick actions title"))
                .font(AppFonts.serif(18, weight: .semibold))
                .foregroundColor(.midnightSpruce)
                .padding(.top, 16)
            Button(action: {
                Haptics.selection()
                onScanBarcode()
            }) {
                HStack {
                    Image(systemName: "barcode.viewfinder")
                    Text("tab.scan".localized())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.midnightSpruce)
                .foregroundColor(.nordicBone)
                .cornerRadius(12)
            }
            .accessibilityIdentifier("quickAdd.scanBarcode")
            Button(action: {
                Haptics.selection()
                onScanPlate()
            }) {
                HStack {
                    Image(systemName: "fork.knife")
                    Text("tab.plate".localized())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cardSurface)
                .foregroundColor(.midnightSpruce)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
            }
            .accessibilityIdentifier("quickAdd.scanPlate")
            Button(action: {
                Haptics.selection()
                onUploadPlate()
            }) {
                HStack {
                    Image(systemName: "photo")
                    Text(NSLocalizedString("plate.upload_photo", comment: "Upload photo"))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cardSurface)
                .foregroundColor(.midnightSpruce)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
            }
            .accessibilityIdentifier("quickAdd.uploadPhoto")
            Spacer()
        }
        .padding(20)
        .presentationDetents([.height(quickActionSheetHeight)])
        .accessibilityIdentifier("sheet.quickAdd")
    }

    private var quickActionSheetHeight: CGFloat {
        let h = UIScreen.main.bounds.height
        return min(max(h * 0.28, 220), 340)
    }
}

private enum Haptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// Preview-only: lightweight static actions for Canvas rendering.
#Preview("Quick Add Sheet") {
    QuickAddSheetView(
        onScanBarcode: {},
        onScanPlate: {},
        onUploadPlate: {}
    )
}
