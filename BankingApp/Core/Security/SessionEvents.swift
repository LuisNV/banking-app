import Foundation

extension Notification.Name {
    /// Phát khi không làm mới được phiên (refresh token hết hạn, bị thu hồi hoặc không còn).
    /// Lúc này token trên máy đã bị xoá; app cần đưa người dùng về màn đăng nhập.
    static let sessionExpired = Notification.Name("auth.sessionExpired")
}
