import Foundation

/// `data` trả về sau khi upload ảnh đại diện. Chấp nhận nhiều dạng để không phụ thuộc chặt vào backend:
/// - `"https://..."` (chuỗi URL)
/// - `{"avatarUrl": "..."}` / `{"avatar_url": "..."}` / `{"url": "..."}` (có thể là cả object user)
/// - `null` hoặc không có body
struct AvatarResponseDTO: DefaultDecodable, Equatable {
    let avatarUrl: String?
    let address: String?
    /// "MALE" / "FEMALE" / "OTHER".
    let gender: String?
    let emailVerified: Bool?

    init() { avatarUrl = nil }

    init(avatarUrl: String?) { self.avatarUrl = avatarUrl }

    private enum CodingKeys: String, CodingKey {
        case avatarUrl, url
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let string = try? single.decode(String.self) {
            avatarUrl = string
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
            ?? container.decodeIfPresent(String.self, forKey: .url)
    }
}

/// `data` của `GET v1/auth/me`. Ví dụ server trả:
/// ```json
/// {"id": 1, "fullName": "Nguyen Van A", "email": "user@example.com", "phone": "0901234567",
///  "address": "123 Le Loi, Q1, HCM", "gender": "MALE", "dateOfBirth": "1995-05-20",
///  "avatarUrl": "https://res.cloudinary.com/...", "emailVerified": true}
/// ```
/// APIClient đã đổi snake_case → camelCase, nên `full_name` và `fullName` đều đọc được.
/// Chấp nhận thêm vài tên khác (`name`, `phoneNumber`, `dateOfBirth`, `dob`, `avatar`)
/// và `id` dạng số, để không phụ thuộc chặt vào backend.
struct UserProfileDTO: Decodable, Equatable {
    let id: String
    let fullName: String
    let email: String?
    let username: String?
    let phone: String?
    /// Chuỗi ngày: "yyyy-MM-dd" hoặc ISO 8601.
    let birthDate: String?
    let avatarUrl: String?

    init(
        id: String,
        fullName: String,
        email: String?,
        username: String?,
        phone: String?,
        birthDate: String?,
        avatarUrl: String?,
        address: String? = nil,
        gender: String? = nil,
        emailVerified: Bool? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.username = username
        self.phone = phone
        self.birthDate = birthDate
        self.avatarUrl = avatarUrl
        self.address = address
        self.gender = gender
        self.emailVerified = emailVerified
    }

    private enum CodingKeys: String, CodingKey {
        case id, fullName, name, email, username
        case phone, phoneNumber
        case birthDate, dateOfBirth, dob, birthday
        case avatarUrl, avatar
        case address, gender, emailVerified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? container.decode(String.self, forKey: .id) {
            id = text
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        let email = try container.decodeIfPresent(String.self, forKey: .email)
        let username = try container.decodeIfPresent(String.self, forKey: .username)
        self.email = email
        self.username = username
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? username ?? email ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
            ?? container.decodeIfPresent(String.self, forKey: .phoneNumber)
        birthDate = try container.decodeIfPresent(String.self, forKey: .birthDate)
            ?? container.decodeIfPresent(String.self, forKey: .dateOfBirth)
            ?? container.decodeIfPresent(String.self, forKey: .dob)
            ?? container.decodeIfPresent(String.self, forKey: .birthday)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
            ?? container.decodeIfPresent(String.self, forKey: .avatar)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified)
    }

    func toDomain() -> UserProfile {
        UserProfile(
            id: id,
            fullName: fullName,
            email: email.nilIfBlank,
            username: username.nilIfBlank,
            phone: phone.nilIfBlank,
            birthDate: birthDate.flatMap(Self.parseDate),
            avatarURL: avatarUrl.nilIfBlank.flatMap(URL.init(string:)),
            address: address.nilIfBlank,
            gender: gender.flatMap(UserProfile.Gender.init(apiValue:)),
            isEmailVerified: emailVerified
        )
    }

    static func parseDate(_ text: String) -> Date? {
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = .current
        dayFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dayFormatter.date(from: text) { return date }

        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: text)
    }
}

private extension Optional where Wrapped == String {
    var nilIfBlank: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
