import Alamofire
import Foundation

enum ProfileEndpoint: Endpoint {
    /// `POST v1/users/me/avatar`, multipart field `file`.
    case uploadAvatar(jpegData: Data)

    var path: String {
        switch self {
        case .uploadAvatar: return "v1/users/me/avatar"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .uploadAvatar: return .post
        }
    }

    var files: [UploadFile]? {
        switch self {
        case .uploadAvatar(let data):
            return [UploadFile(fieldName: "file", fileName: "avatar.jpg", mimeType: "image/jpeg", data: data)]
        }
    }

    /// Upload ảnh trên mạng yếu cần lâu hơn mức 30 giây mặc định.
    var timeout: TimeInterval? {
        switch self {
        case .uploadAvatar: return 120
        }
    }

    // requiresAuth mặc định là true → tự gắn Bearer token và tự refresh khi 401.
}
