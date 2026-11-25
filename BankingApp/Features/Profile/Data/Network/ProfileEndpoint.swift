import Alamofire
import Foundation

enum ProfileEndpoint: Endpoint {
    /// `GET v1/auth/me` + Bearer token.
    case me
    /// `PUT v1/users/me` + Bearer token, body JSON.
    case updateMe(UpdateProfileRequestDTO)

    /// `POST v1/users/me/avatar`, multipart field `file`.
    case uploadAvatar(jpegData: Data)

    var path: String {
        switch self {
        case .me: return "v1/auth/me"
        case .updateMe: return "v1/users/me"
        case .uploadAvatar: return "v1/users/me/avatar"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .me: return .get
        case .updateMe: return .put
        case .uploadAvatar: return .post
        }
    }

    var files: [UploadFile]? {
        switch self {
        case .uploadAvatar(let data):
            return [UploadFile(fieldName: "file", fileName: "avatar.jpg", mimeType: "image/jpeg", data: data)]
        case .me, .updateMe:
            return nil
        }
    }

    var body: (any Encodable)? {
        switch self {
        case .updateMe(let dto): return dto
        case .me, .uploadAvatar: return nil
        }
    }

    /// Upload ảnh trên mạng yếu cần lâu hơn mức 30 giây mặc định.
    var timeout: TimeInterval? {
        switch self {
        case .uploadAvatar: return 120
        case .me, .updateMe: return nil
        }
    }

    // requiresAuth mặc định là true → tự gắn Bearer token và tự refresh khi 401.
}
