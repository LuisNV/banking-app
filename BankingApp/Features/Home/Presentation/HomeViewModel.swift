import Factory
import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    let user: User?
    private(set) var isLoggingOut = false

    // MARK: Avatar
    private(set) var isUploadingAvatar = false
    /// Ảnh vừa upload thành công (hiện ngay, không cần tải lại từ server).
    private(set) var avatarImageData: Data?
    /// URL ảnh server trả về (nếu có).
    private(set) var avatarURL: URL?
    var errorMessage: String?

    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    private let logoutUseCase: LogoutUseCaseProtocol
    private let uploadAvatarUseCase: UploadAvatarUseCaseProtocol
    private let prepareImage: (Data) -> Data?
    private let onLoggedOut: () -> Void

    init(
        user: User?,
        logoutUseCase: LogoutUseCaseProtocol = Container.shared.logoutUseCase(),
        uploadAvatarUseCase: UploadAvatarUseCaseProtocol = Container.shared.uploadAvatarUseCase(),
        prepareImage: @escaping (Data) -> Data? = AvatarImageProcessor.jpegData(from:),
        onLoggedOut: @escaping () -> Void
    ) {
        self.user = user
        self.logoutUseCase = logoutUseCase
        self.uploadAvatarUseCase = uploadAvatarUseCase
        self.prepareImage = prepareImage
        self.onLoggedOut = onLoggedOut
    }

    func logout() async {
        isLoggingOut = true
        await logoutUseCase.execute()
        isLoggingOut = false
        onLoggedOut()
    }

    /// - Parameter pickedData: dữ liệu gốc của ảnh người dùng chọn (HEIC/PNG/JPEG...).
    func uploadAvatar(from pickedData: Data) async {
        guard !isUploadingAvatar else { return }
        guard let jpegData = prepareImage(pickedData) else {
            errorMessage = ProfileError.invalidImage.errorDescription
            return
        }

        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        do {
            let url = try await uploadAvatarUseCase.execute(jpegData: jpegData)
            avatarImageData = jpegData
            avatarURL = url
        } catch ProfileError.sessionExpired {
            // AppRouter đã tự đưa về màn đăng nhập và báo hết phiên, không cần báo thêm.
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? ProfileError.unknown.errorDescription
        }
    }
}
