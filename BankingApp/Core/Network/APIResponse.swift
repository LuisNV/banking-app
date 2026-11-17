import Foundation

/// Lớp bọc chung cho phản hồi từ API.
struct APIResponse<Payload: Decodable>: Decodable {
    let code: Int
    let httpStatus: Int
    let message: String
    let data: Payload?
    let traceId: String?
}

/// Dùng cho endpoint không trả dữ liệu và để đọc metadata mà bỏ qua payload.
struct EmptyResponseDTO: Decodable {}
