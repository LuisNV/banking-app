import SwiftUI

/// Khung sau đăng nhập: nội dung từng tab + thanh tab nổi.
struct HomeView: View {
    @State private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            switch viewModel.selectedTab {
            case .home:
                HomeDashboardView(viewModel: viewModel)
            case .profile:
                ProfileTabView(viewModel: viewModel)
            case .lessons, .review:
                ComingSoonTabView(tab: viewModel.selectedTab)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $viewModel.selectedTab)
        }
        .alert(
            "Không thể cập nhật ảnh",
            isPresented: $viewModel.isShowingError,
            presenting: viewModel.errorMessage
        ) { _ in
            Button("Đóng", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }
}
