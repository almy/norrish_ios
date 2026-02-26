import SwiftUI
import UIKit

struct TabWithFloatingAddButton<Content: View>: View {
    let onAdd: () -> Void
    let onScanProduct: () -> Void
    let onAnalyzePlate: () -> Void
    @ViewBuilder let content: Content

    init(
        onAdd: @escaping () -> Void,
        onScanProduct: @escaping () -> Void,
        onAnalyzePlate: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onAdd = onAdd
        self.onScanProduct = onScanProduct
        self.onAnalyzePlate = onAnalyzePlate
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        Haptics.impact(.medium)
                        onAdd()
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.nordicBone)
                            .padding()
                    }
                    .accessibilityIdentifier("fab.quickAdd")
                    .contextMenu {
                        Button {
                            Haptics.selection()
                            onScanProduct()
                        } label: {
                            Label("Scan Product", systemImage: "barcode.viewfinder")
                        }

                        Button {
                            Haptics.selection()
                            onAnalyzePlate()
                        } label: {
                            Label("Analyze Plate", systemImage: "camera.viewfinder")
                        }
                    }
                    .background(Color.midnightSpruce)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

private enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// Preview-only: demonstrates wrapper layout with static placeholder content.
#Preview("Tab Wrapper") {
    TabWithFloatingAddButton(onAdd: {}, onScanProduct: {}, onAnalyzePlate: {}) {
        ZStack {
            Color.nordicBone.ignoresSafeArea()
            Text("Wrapped Content")
                .font(AppFonts.serif(24, weight: .semibold))
                .foregroundColor(.midnightSpruce)
        }
    }
}
