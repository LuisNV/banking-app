import Alamofire
import Foundation

/// Mô tả một API endpoint. Mỗi feature tự khai báo enum endpoint của mình.
protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var body: (any Encodable)? { get }
    var queryItems: [String: String]? { get }
    var requiresAuth: Bool { get }
}

extension Endpoint {
    var body: (any Encodable)? { nil }
    var queryItems: [String: String]? { nil }
    var requiresAuth: Bool { true }
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
