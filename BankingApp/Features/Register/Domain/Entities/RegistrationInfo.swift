import Foundation

/// Thông tin người dùng nhập ở bước 1 của luồng đăng ký.
struct RegistrationInfo: Equatable {
    var fullName: String
    var email: String
    var phone: String
    var birthDate: Date

    /// Dạng chuẩn hoá để gửi lên server: bỏ khoảng trắng thừa, email chữ thường, số điện thoại chỉ còn chữ số.
    var normalized: RegistrationInfo {
        RegistrationInfo(
            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isWhitespace).joined(separator: " "),
            email: RegistrationValidator.normalizedEmail(email),
            phone: RegistrationValidator.normalizedPhone(phone),
            birthDate: birthDate
        )
    }
}

enum RegistrationField: CaseIterable, Hashable {
    case fullName, email, phone, birthDate
}
