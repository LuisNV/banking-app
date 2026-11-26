import SwiftUI

/// Lớp phủ loading dùng chung khi đang thực hiện một thao tác (đăng xuất, lưu…):
/// nền tối mờ chặn thao tác, ở giữa là icon app với vòng xoay bao quanh. Không có chữ trên màn hình;
/// `message` chỉ dùng cho VoiceOver.
struct LoadingOverlay: View {
    var message: LocalizedStringKey?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            ZStack {
                SpinnerRing(lineWidth: 4)
                    .frame(width: 96, height: 96)
                BrandLogo(size: 64)
            }
        }
        // Chặn tap xuyên xuống nội dung bên dưới khi đang loading.
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(message.map { Text($0) } ?? Text("Đang tải"))
    }
}

/// Vòng xoay trắng: nền vòng mờ, một nửa vòng sáng chạy quanh.
/// Bật "Giảm chuyển động" thì vòng đứng yên.
struct SpinnerRing: View {
    var lineWidth: CGFloat = 4
    var color: Color = .white

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSpinning = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    reduceMotion ? nil : .linear(duration: 0.9).repeatForever(autoreverses: false),
                    value: isSpinning
                )
        }
        .padding(lineWidth / 2)
        .onAppear { isSpinning = true }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Hiển thị `LoadingOverlay` phủ lên view khi `isLoading` là `true`.
    ///
    ///     content.loadingOverlay(viewModel.isLoading, message: "Đang đăng nhập...")
    func loadingOverlay(_ isLoading: Bool, message: LocalizedStringKey? = nil) -> some View {
        overlay {
            if isLoading {
                LoadingOverlay(message: message)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Nội dung màn hình")
        Button("Nút bên dưới") {}
            .buttonStyle(PrimaryButtonStyle())
    }
    .padding(AppMetrics.screenPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .loadingOverlay(true, message: "Đang tải...")
}
