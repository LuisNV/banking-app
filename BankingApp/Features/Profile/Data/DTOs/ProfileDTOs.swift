import Foundation

/// `data` trả về sau khi upload ảnh đại diện. Chấp nhận nhiều dạng để không phụ thuộc chặt vào backend:
/// - `"https://..."` (chuỗi URL)
/// - `{"avatarUrl": "..."}` / `{"avatar_url": "..."}` / `{"url": "..."}` (có thể là cả object user)
/// - `null` hoặc không có body
struct AvatarResponseDTO: DefaultDecodable, Equatable {
    let avatarUrl: String?

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
