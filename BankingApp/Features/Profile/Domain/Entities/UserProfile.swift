import Foundation

/// Thông tin tài khoản của người đang đăng nhập (`GET v1/auth/me`).
struct UserProfile: Equatable {
    let id: String
    let fullName: String
    let email: String?
    let username: String?
    let phone: String?
    let birthDate: Date?
    let avatarURL: URL?
    var address: String?
    var gender: Gender?
    /// `nil` nếu server không gửi.
    var isEmailVerified: Bool?

    enum Gender: Equatable, CaseIterable, Hashable {
        case male, female, other

        /// Từ giá trị server: "MALE" / "FEMALE" / "OTHER" (không phân biệt hoa thường).
        init?(apiValue: String) {
            switch apiValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
            case "MALE": self = .male
            case "FEMALE": self = .female
            case "OTHER": self = .other
            default: return nil
            }
        }

        /// Giá trị gửi lên server.
        var apiValue: String {
            switch self {
            case .male: return "MALE"
            case .female: return "FEMALE"
            case .other: return "OTHER"
            }
        }

        var title: String {
            switch self {
            case .male: return "Nam"
            case .female: return "Nữ"
            case .other: return "Khác"
            }
        }
    }
}
