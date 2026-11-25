import Foundation

protocol ProfileRepository {
    /// Thông tin tài khoản hiện tại.
    func currentProfile() async throws -> UserProfile
    /// Ghi đè hồ sơ, trả về hồ sơ mới. Lỗi: `ProfileUpdateError`.
    func updateProfile(_ update: ProfileUpdate) async throws -> UserProfile

    /// Gửi ảnh JPEG lên server. Trả về URL ảnh mới nếu server có trả.
    func uploadAvatar(jpegData: Data) async throws -> URL?
}
