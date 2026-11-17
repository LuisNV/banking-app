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
    let code: Int
    let httpStatus: Int
    let message: String
    let traceId: String?
}

/// Dùng cho endpoint không trả dữ liệu.
struct EmptyResponseDTO: Decodable {}
