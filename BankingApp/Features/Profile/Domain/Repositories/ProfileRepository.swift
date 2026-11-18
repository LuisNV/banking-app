import Foundation

protocol ProfileRepository {
    /// Gửi ảnh JPEG lên server. Trả về URL ảnh mới nếu server có trả.
    func uploadAvatar(jpegData: Data) async throws -> URL?
}
