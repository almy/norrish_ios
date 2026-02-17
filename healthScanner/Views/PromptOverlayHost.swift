import SwiftUI

/// Lightweight host for prompt/overlay presentation.
/// Currently a pass-through, but you can add overlay layers or environment here.
struct PromptOverlayHost<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
    }
}

// Preview-only: validates pass-through host composition.
#Preview("Prompt Host") {
    PromptOverlayHost {
        ZStack {
            Color.nordicBone.ignoresSafeArea()
            Text("Prompt Host Content")
                .font(AppFonts.sans(16, weight: .semibold))
                .foregroundColor(.midnightSpruce)
        }
    }
}
