import Combine
import SwiftUI

struct RootView: View {
    @State private var router = AppRouter()
    /// Màn "Mở app" che nội dung một lúc ngắn khi khởi động (nối tiếp Launch Screen của iOS).
    @State private var isShowingSplash = true

    /// Thời gian tối thiểu hiện màn "Mở app", đủ để đọc tên app mà không làm chậm người dùng.
    private static let splashDuration: Duration = .milliseconds(900)

    var body: some View {
        ZStack {
            content
            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: Self.splashDuration)
            withAnimation(.easeOut(duration: 0.35)) { isShowingSplash = false }
        }
    }

    private var content: some View {
        Group {
            switch router.route {
            case .login:
                LoginView(
                    viewModel: LoginViewModel(
                        prefilledUsername: router.prefilledUsername,
                        onAuthenticated: { [router] session in
                            router.showHome(with: session)
                        }
                    ),
                    onRegister: { [router] in router.showRegister() }
                )
                .transition(.opacity)

            case .register:
                RegisterView(
                    viewModel: RegisterViewModel(
                        onCancel: { [router] in router.showLogin() },
                        // Đăng ký xong server trả token: vào thẳng app.
                        onFinished: { [router] session in router.showHome(with: session) }
                    )
                )
                .transition(.move(edge: .trailing))

            case .home(let user):
                HomeView(
                    viewModel: HomeViewModel(user: user, onLoggedOut: { [router] in
                        router.showLogin()
                    })
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: router.route)
        .onReceive(
            NotificationCenter.default.publisher(for: .sessionExpired)
                .receive(on: DispatchQueue.main)
        ) { _ in
            router.handleSessionExpired()
        }
        .alert(
            "Phiên đăng nhập hết hạn",
            isPresented: $router.isShowingSessionExpired,
            presenting: router.sessionExpiredMessage
        ) { _ in
            Button("Đăng nhập lại", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }
}
