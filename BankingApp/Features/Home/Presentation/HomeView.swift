import SwiftUI

/// Màn hình sau đăng nhập (placeholder). Thay bằng dashboard thật.
struct HomeView: View {
    @State private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Xin chào,").foregroundStyle(AppColor.textSecondary)
                        Text(viewModel.user?.fullName ?? "Chào mừng bạn").font(.title2.bold())
                    }
                    .padding(.vertical, 8)
                }
                Section {
                    Button(role: .destructive) {
                        Task { await viewModel.logout() }
                    } label: {
                        Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(viewModel.isLoggingOut)
                }
            }
            .navigationTitle("Trang chủ")
        }
    }
}
