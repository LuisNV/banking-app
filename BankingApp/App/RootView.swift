import Combine
import SwiftUI

struct RootView: View {
    @State private var router = AppRouter()

    var body: some View {
        Group {
            switch router.route {
            case .login:
                LoginView(
                    viewModel: LoginViewModel(onAuthenticated: { [router] session in
                        router.showHome(with: session)
                    })
                )
                .transition(.opacity)

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
