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
