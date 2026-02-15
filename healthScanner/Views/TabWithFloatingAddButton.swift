import SwiftUI

struct TabWithFloatingAddButton<Content: View>: View {
    let onAdd: () -> Void
    @ViewBuilder let content: Content

    init(onAdd: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onAdd = onAdd
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.nordicBone)
                            .padding()
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
