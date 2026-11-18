import Alamofire
import Foundation

/// Mô tả một API endpoint. Mỗi feature tự khai báo enum endpoint của mình.
protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var body: (any Encodable)? { get }
    var queryItems: [String: String]? { get }
    var requiresAuth: Bool { get }
    /// Có giá trị → gửi `multipart/form-data` (như `curl -F "file=@..."`), bỏ qua `body`.
    var files: [UploadFile]? { get }
    /// Các field chữ đi kèm khi upload (như `curl -F "key=value"`).
    var formFields: [String: String]? { get }
    /// Thời gian chờ riêng cho endpoint (giây). `nil` → dùng mặc định của APIClient.
    var timeout: TimeInterval? { get }
}

extension Endpoint {
    var body: (any Encodable)? { nil }
    var queryItems: [String: String]? { nil }
    var requiresAuth: Bool { true }
    var files: [UploadFile]? { nil }
    var formFields: [String: String]? { nil }
    var timeout: TimeInterval? { nil }
}

/// Một file gửi lên theo `multipart/form-data`.
struct UploadFile: Equatable {
    /// Tên field server đọc, vd. `"file"` trong `-F "file=@avatar.jpg"`.
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

/// Bọc một giá trị Encodable bất kỳ để truyền vào Alamofire.
struct AnyEncodable: Encodable, @unchecked Sendable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        encodeClosure = { encoder in try value.encode(to: encoder) }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
