import Foundation

/// Lớp bọc chung cho phản hồi từ API.
struct APIResponse<Payload: Decodable>: Decodable {
    let code: Int
    let httpStatus: Int
    let message: String
    let data: Payload?
    let traceId: String?
}

/// Chỉ đọc phần metadata của envelope, bỏ qua `data`
/// (nên dùng được cho mọi kiểu payload: object, mảng, chuỗi, null).
struct APIResponseMeta: Decodable {
    /// Mã số của server. `code` dạng chữ (vd. "SESSION_UNKNOWN") được đổi thành
    /// `APIResponseMeta.namedErrorCode` để vẫn đọc được `message` và báo lỗi đúng.
    let code: Int
    let httpStatus: Int
    let message: String
    let traceId: String?

    /// Dùng cho `code` dạng chữ không phải số.
    static let namedErrorCode = -1

    private enum CodingKeys: String, CodingKey {
        case code, httpStatus, message, traceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let number = try? container.decode(Int.self, forKey: .code) {
            code = number
        } else {
            let text = try container.decode(String.self, forKey: .code)
            if let number = Int(text) {
                code = number
            } else {
                code = ["OK", "SUCCESS"].contains(text.uppercased()) ? 0 : Self.namedErrorCode
            }
        }
        httpStatus = try container.decode(Int.self, forKey: .httpStatus)
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        traceId = try container.decodeIfPresent(String.self, forKey: .traceId)
    }
}

/// Kiểu phản hồi chấp nhận `data` rỗng/null: APIClient trả về `init()` thay vì báo lỗi decode.
protocol DefaultDecodable: Decodable {
    init()
}

/// Dùng cho endpoint không trả dữ liệu.
struct EmptyResponseDTO: DefaultDecodable {}
