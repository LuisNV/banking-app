import SwiftUI

/// Màn "Mở app": nối tiếp Launch Screen của iOS (cùng nền xanh, cùng ảnh `LaunchLogo`
/// đặt đúng giữa màn hình) nên khi chuyển sang không bị giật. Thêm tên app, khẩu hiệu,
/// vòng xoay và phiên bản.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    @State private var showsDetails = false

    var body: some View {
        ZStack {
            AppColor.brand.ignoresSafeArea()

            // Logo ở chính giữa (trùng vị trí với Launch Screen); chữ nằm ngay bên dưới.
            Image("LaunchLogo")
                .scaleEffect(isBreathing ? 1.04 : 1)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isBreathing
                )
                .overlay(alignment: .bottom) {
                    VStack(spacing: 6) {
                        Text("TingTing")
                            .font(.largeTitle.bold())
                        Text("Học tiếng Trung mỗi ngày")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .foregroundStyle(.white)
                    .fixedSize()
                    // Đỉnh khối chữ cách đáy logo 24 pt.
                    .alignmentGuide(.bottom) { $0[.top] - 24 }
                    .opacity(showsDetails ? 1 : 0)
                }
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Đang tải dữ liệu học…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Text("Phiên bản \(Bundle.main.shortVersion)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 16)
            }
            .padding(.bottom, 8)
            .opacity(showsDetails ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("TingTing đang tải")
        .onAppear {
            isBreathing = true
            withAnimation(.easeOut(duration: 0.25)) { showsDetails = true }
        }
    }
}

#Preview {
    SplashView()
}
