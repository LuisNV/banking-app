import SwiftUI

/// Lớp phủ loading dùng chung: nền tối nhẹ phủ toàn màn hình, chặn thao tác,
/// ở giữa là thẻ chứa vòng xoay và (tuỳ chọn) dòng mô tả.
struct LoadingOverlay: View {
    var message: LocalizedStringKey?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppColor.brand)

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(minWidth: 120, minHeight: 120)
            .background(
                AppColor.card,
                in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
            )
            .shadow(color: .black.opacity(0.15), radius: 16, y: 4)
        }
        // Chặn tap xuyên xuống nội dung bên dưới khi đang loading.
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(message.map { Text($0) } ?? Text("Đang tải"))
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
