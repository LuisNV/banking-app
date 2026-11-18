import Foundation
import Observation

/// Điều hướng cấp ứng dụng: quyết định đang ở luồng chưa đăng nhập hay đã đăng nhập.
@MainActor
@Observable
final class AppRouter {
    enum Route: Equatable {
        case login
        case home(User?)
    }

    private(set) var route: Route = .login
    /// Thông báo hiện trên màn đăng nhập khi bị đẩy ra vì hết phiên.
    var sessionExpiredMessage: String?

    var isShowingSessionExpired: Bool {
        get { sessionExpiredMessage != nil }
        set { if !newValue { sessionExpiredMessage = nil } }
    }

    func showHome(with session: AuthSession) {
        route = .home(session.user)
    }

    func showLogin() {
        route = .login
    }

    /// Gọi khi nhận `Notification.Name.sessionExpired`. Chỉ có tác dụng khi đang ở luồng đã đăng nhập,
    /// nên nhiều request cùng hết phiên cũng chỉ chuyển màn và báo một lần.
    func handleSessionExpired() {
        guard case .home = route else { return }
        route = .login
        sessionExpiredMessage = AuthError.sessionExpired.errorDescription
    }
}
