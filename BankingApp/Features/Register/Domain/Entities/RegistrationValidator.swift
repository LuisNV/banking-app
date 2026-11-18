import Foundation

/// Kiểm tra thông tin đăng ký. Thuần logic, không phụ thuộc UI hay mạng nên dễ test.
enum RegistrationValidator {
    /// Trả về lỗi theo từng trường; rỗng nghĩa là hợp lệ.
    static func errors(for info: RegistrationInfo, now: Date = Date()) -> [RegistrationField: String] {
        var errors: [RegistrationField: String] = [:]

        let name = info.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            errors[.fullName] = "Vui lòng nhập họ và tên."
        } else if name.count < 2 {
            errors[.fullName] = "Họ và tên quá ngắn."
        }

        let email = normalizedEmail(info.email)
        if email.isEmpty {
            errors[.email] = "Vui lòng nhập email."
        } else if !isValidEmail(email) {
            errors[.email] = "Email không hợp lệ."
        }

        let phone = normalizedPhone(info.phone)
        if phone.isEmpty {
            errors[.phone] = "Vui lòng nhập số điện thoại."
        } else if !isValidPhone(phone) {
            errors[.phone] = "Số điện thoại cần đủ 10 chữ số, bắt đầu bằng 0."
        }

        if info.birthDate > now {
            errors[.birthDate] = "Ngày sinh không hợp lệ."
        }
        return errors
    }

    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValidEmail(_ email: String) -> Bool {
        email.range(of: #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    }

    /// Chỉ giữ chữ số; "+84 912..." được đổi thành "0912...".
    static func normalizedPhone(_ phone: String) -> String {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter { $0.isASCII && $0.isNumber }
        if trimmed.hasPrefix("+84") {
            return "0" + digits.dropFirst(2)
        }
        return digits
    }

    static func isValidPhone(_ phone: String) -> Bool {
        phone.count == 10 && phone.hasPrefix("0")
    }
}
