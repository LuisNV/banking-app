import Foundation

enum ProfileError: LocalizedError, Equatable {
    case invalidImage
    case imageTooLarge(maxMegabytes: Int)
    case sessionExpired
    case network
    case api(message: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Không đọc được ảnh. Vui lòng chọn ảnh khác."
        case .imageTooLarge(let max): return "Ảnh quá lớn. Vui lòng chọn ảnh dưới \(max) MB."
        case .sessionExpired: return "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
        case .network: return "Không thể kết nối. Vui lòng kiểm tra mạng và thử lại."
        case .api(let message): return message
        case .unknown: return "Không thể cập nhật ảnh đại diện. Vui lòng thử lại."
        }
    }
}
