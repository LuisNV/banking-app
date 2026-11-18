import Combine
import SwiftUI

struct RootView: View {
    @State private var router = AppRouter()

    var body: some View {
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
                        onFinished: { [router] email in router.showLogin(prefilledUsername: email) }
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
