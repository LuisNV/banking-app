import Foundation

/// Dữ liệu sửa hồ sơ (`PUT v1/users/me`).
struct ProfileUpdate: Equatable {
    var fullName: String
    var phone: String
    var address: String
    var gender: UserProfile.Gender?
    var birthDate: Date?
    /// Email mới. `nil` = giữ nguyên email cũ.
    var email: String?
    /// Chỉ gửi khi đổi email.
    var currentPassword: String?
}

enum ProfileField: Hashable, CaseIterable {
    case fullName, phone, address, birthDate, email
}

/// Quy tắc kiểm tra giống phía server, để báo lỗi ngay trên form mà không cần gọi API.
enum ProfileUpdateValidator {
    static let maxFullName = 150
    static let maxPhone = 30
    static let maxAddress = 500
    static let maxEmail = 254

    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Bỏ khoảng trắng hai đầu và chuyển chữ thường (server làm y như vậy).
    static func normalizedEmail(_ email: String) -> String {
        trimmed(email).lowercased()
    }

    /// Bản đã chuẩn hoá để gửi đi.
    static func normalized(_ update: ProfileUpdate) -> ProfileUpdate {
        var result = update
        result.fullName = trimmed(update.fullName)
        result.phone = trimmed(update.phone)
        result.address = trimmed(update.address)
        result.email = update.email.map(normalizedEmail)
        return result
    }

    /// Lỗi theo từng trường; rỗng nghĩa là hợp lệ.
    static func errors(for update: ProfileUpdate, now: Date = Date(), calendar: Calendar = .current) -> [ProfileField: String] {
        let value = normalized(update)
        var errors: [ProfileField: String] = [:]

        if value.fullName.isEmpty {
            errors[.fullName] = "Vui lòng nhập họ và tên."
        } else if value.fullName.count > maxFullName {
            errors[.fullName] = "Họ và tên tối đa \(maxFullName) ký tự."
        }

        if value.phone.isEmpty {
            errors[.phone] = "Vui lòng nhập số điện thoại."
        } else if value.phone.count > maxPhone {
            errors[.phone] = "Số điện thoại tối đa \(maxPhone) ký tự."
        }

        if value.address.isEmpty {
            errors[.address] = "Vui lòng nhập địa chỉ."
        } else if value.address.count > maxAddress {
            errors[.address] = "Địa chỉ tối đa \(maxAddress) ký tự."
        }

        if let birthDate = value.birthDate,
           calendar.startOfDay(for: birthDate) > calendar.startOfDay(for: now) {
            errors[.birthDate] = "Ngày sinh không được ở tương lai."
        }

        if let email = value.email {
            if email.isEmpty {
                errors[.email] = "Vui lòng nhập email."
            } else if email.count > maxEmail {
                errors[.email] = "Email tối đa \(maxEmail) ký tự."
            } else if !RegistrationValidator.isValidEmail(email) {
                errors[.email] = "Email không hợp lệ."
            }
        }
        return errors
    }

    /// Đổi email khi email mới (đã chuẩn hoá) khác email hiện tại.
    static func isChangingEmail(_ newEmail: String?, current: String?) -> Bool {
        guard let newEmail else { return false }
        return normalizedEmail(newEmail) != normalizedEmail(current ?? "")
    }
}

/// Lỗi khi lưu hồ sơ. Mã 1001–1004 theo hợp đồng của backend.
enum ProfileUpdateError: LocalizedError, Equatable {
    /// Lỗi kiểm tra phía app.
    case invalid([ProfileField: String])
    /// 1001: đổi email nhưng thiếu mật khẩu.
    case passwordRequired
    /// 1002: mật khẩu hiện tại sai.
    case wrongPassword
    /// 1003: email đã có người dùng.
    case emailTaken
    /// 1004: số điện thoại đã có người dùng.
    case phoneTaken
    /// 401 sau khi refresh thất bại.
    case sessionExpired
    /// 404: tài khoản trong token không còn tồn tại.
    case accountNotFound
    case network
    /// 400 hoặc lỗi khác kèm thông báo của server.
    case api(message: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalid: return "Vui lòng kiểm tra lại thông tin."
        case .passwordRequired: return "Vui lòng nhập mật khẩu hiện tại để đổi email."
        case .wrongPassword: return "Mật khẩu hiện tại không đúng."
        case .emailTaken: return "Email này đã được sử dụng."
        case .phoneTaken: return "Số điện thoại này đã được sử dụng."
        case .sessionExpired: return "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
        case .accountNotFound: return "Tài khoản không còn tồn tại. Vui lòng đăng nhập lại."
        case .network: return "Không thể kết nối. Vui lòng kiểm tra mạng và thử lại."
        case .api(let message): return message
        case .unknown: return "Không thể lưu thông tin. Vui lòng thử lại."
        }
    }
}
