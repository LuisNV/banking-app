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
        // Thanh tab nổi phía trên nội dung (nội dung cuộn mờ phía sau). Mỗi tab tự chừa chỗ
        // ở cuối danh sách bằng `.floatingTabBarInset()` để mục cuối không bị thanh tab che.
        .overlay(alignment: .bottom) {
            if !viewModel.isTabBarHidden {
                FloatingTabBar(selection: $viewModel.selectedTab)
                    .padding(.bottom, FloatingTabBar.bottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await viewModel.loadProfile() }
        // Lỗi tải không chặn thao tác: báo bằng toast, có "Thử lại".
        .onChange(of: viewModel.profileErrorMessage) { _, message in
            guard let message else { return }
            AppPopupCenter.shared.showToast(AppToast(
                title: "Không tải được thông tin tài khoản",
                message: message,
                actionTitle: "Thử lại",
                action: { [viewModel] in Task { await viewModel.loadProfile(force: true) } }
            ))
        }
        .task { await viewModel.learningSettings.load() }
        .overlay {
            if viewModel.isLoggingOut {
                LoadingOverlay(message: "Đang đăng xuất...")
            }
        }
        .errorPopup(
            "Không thể cập nhật ảnh",
            isPresented: $viewModel.isShowingError,
            message: viewModel.errorMessage
        )
    }
}
