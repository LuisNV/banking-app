import Foundation
import Observation

/// Điều hướng cấp ứng dụng: quyết định đang ở luồng chưa đăng nhập hay đã đăng nhập.
@MainActor
@Observable
final class AppRouter {
    enum Route: Equatable {
        case login
        case home(User)
    }

    private(set) var route: Route = .login

    func showHome(with session: AuthSession) {
        route = .home(session.user)
    }

    func showLogin() {
        route = .login
    }
}
