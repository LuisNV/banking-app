import SwiftUI

/// Container drawer trượt từ cạnh trái, có nền mờ phía sau và vuốt sang trái để đóng.
/// `drawer` nhận safe-area insets để tự đệm phần header tràn lên status bar.
struct SideDrawer<Content: View, Drawer: View>: View {
    @Binding var isOpen: Bool
    var width: CGFloat = AppMetrics.drawerWidth
    @ViewBuilder var content: () -> Content
    @ViewBuilder var drawer: (EdgeInsets) -> Drawer

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                content()
                    .accessibilityHidden(isOpen)

                Color.black
                    .opacity(isOpen ? 0.36 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(isOpen)
                    .onTapGesture { isOpen = false }
                    .accessibilityHidden(true)

                drawer(proxy.safeAreaInsets)
                    .frame(width: width)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(AppColor.groupedBackground)
                    .clipShape(
                        UnevenRoundedRectangle(
                            bottomTrailingRadius: 28,
                            topTrailingRadius: 28,
                            style: .continuous
                        )
                    )
                    .shadow(color: .black.opacity(isOpen ? 0.18 : 0), radius: 24, x: 8)
                    .offset(x: isOpen ? min(0, dragOffset) : -(width + 24))
                    .ignoresSafeArea(edges: .vertical)
                    .gesture(closeGesture)
                    .accessibilityAddTraits(.isModal)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isOpen)
        .animation(.interactiveSpring(), value: dragOffset)
    }

    private var closeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                if value.translation.width < -width / 3 || value.predictedEndTranslation.width < -width / 2 {
                    isOpen = false
                }
            }
    }
}
