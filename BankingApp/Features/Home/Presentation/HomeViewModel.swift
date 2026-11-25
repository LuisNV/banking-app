import Factory
import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    enum Tab: Hashable, CaseIterable {
        case home, lessons, review, profile
    }

    let user: User?
    var selectedTab: Tab = .home
    private(set) var isLoggingOut = false

    // MARK: Dashboard
    private(set) var dashboard: HomeDashboard?
    private(set) var isLoadingDashboard = false
    /// Ngày hiển thị ở đầu Trang chủ.
    let today: Date

    // MARK: Profile (`GET v1/auth/me`)
    private(set) var profile: UserProfile?
    private(set) var isLoadingProfile = false
    private(set) var profileErrorMessage: String?

    // MARK: Avatar
    private(set) var isUploadingAvatar = false
    /// Ảnh vừa upload thành công (hiện ngay, không cần tải lại từ server).
    private(set) var avatarImageData: Data?
    /// URL ảnh server trả về sau khi upload (nếu có).
    private var uploadedAvatarURL: URL?

    /// Ảnh vừa upload, không có thì ảnh trong hồ sơ.
    var avatarURL: URL? { uploadedAvatarURL ?? profile?.avatarURL }

    /// Họ tên hiển thị: ưu tiên dữ liệu mới nhất từ `me`.
    var fullName: String? {
        let name = profile?.fullName ?? user?.fullName
        return name?.isEmpty == false ? name : nil
    }

    /// Email (hoặc tên đăng nhập) hiển thị dưới tên.
    var accountSubtitle: String? {
        profile?.email ?? profile?.username ?? user?.username
    }
    var errorMessage: String?

    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    private let logoutUseCase: LogoutUseCaseProtocol
    private let uploadAvatarUseCase: UploadAvatarUseCaseProtocol
    private let getDashboardUseCase: GetHomeDashboardUseCaseProtocol
    private let getMyProfileUseCase: GetMyProfileUseCaseProtocol
    private let pronunciation: PronunciationServiceProtocol
    private let prepareImage: (Data) -> Data?
    private let onLoggedOut: () -> Void

    init(
        user: User?,
        logoutUseCase: LogoutUseCaseProtocol = Container.shared.logoutUseCase(),
        uploadAvatarUseCase: UploadAvatarUseCaseProtocol = Container.shared.uploadAvatarUseCase(),
        getDashboardUseCase: GetHomeDashboardUseCaseProtocol = Container.shared.getHomeDashboardUseCase(),
        getMyProfileUseCase: GetMyProfileUseCaseProtocol = Container.shared.getMyProfileUseCase(),
        pronunciation: PronunciationServiceProtocol = Container.shared.pronunciationService(),
        prepareImage: @escaping (Data) -> Data? = AvatarImageProcessor.jpegData(from:),
        today: Date = Date(),
        onLoggedOut: @escaping () -> Void
    ) {
        self.user = user
        self.logoutUseCase = logoutUseCase
        self.uploadAvatarUseCase = uploadAvatarUseCase
        self.getDashboardUseCase = getDashboardUseCase
        self.getMyProfileUseCase = getMyProfileUseCase
        self.pronunciation = pronunciation
        self.prepareImage = prepareImage
        self.today = today
        self.onLoggedOut = onLoggedOut
    }

    // MARK: Greeting

    /// Tên gọi thân mật: "Nguyễn Minh Anh" → "Minh Anh".
    var displayName: String? {
        let words = (fullName ?? "").split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return nil }
        return words.suffix(words.count >= 3 ? 2 : words.count).joined(separator: " ")
    }

    var greeting: String {
        displayName.map { "Chào, \($0)" } ?? "Xin chào"
    }

    /// Chữ cái đầu cho avatar: "Minh Anh" → "MA".
    var initials: String {
        guard let displayName else { return "" }
        return displayName
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
    }

    /// Vd. "THỨ TƯ, 18 THÁNG 11".
    var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "EEEE, d 'tháng' M"
        return formatter.string(from: today).uppercased(with: formatter.locale)
    }

    // MARK: Actions

    func loadDashboard() async {
        guard dashboard == nil, !isLoadingDashboard else { return }
        isLoadingDashboard = true
        defer { isLoadingDashboard = false }
        dashboard = try? await getDashboardUseCase.execute()
    }

    /// Tải thông tin tài khoản. Mặc định chỉ tải một lần; `force` để tải lại (kéo để làm mới).
    func loadProfile(force: Bool = false) async {
        guard !isLoadingProfile, force || profile == nil else { return }
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        do {
            profile = try await getMyProfileUseCase.execute()
            profileErrorMessage = nil
        } catch ProfileError.sessionExpired {
            // AppRouter đã đưa về màn đăng nhập.
        } catch {
            profileErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? ProfileError.loadFailed.errorDescription
        }
    }

    func playWordOfTheDay() {
        guard let word = dashboard?.wordOfTheDay else { return }
        pronunciation.speak(word.hanzi)
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
            uploadedAvatarURL = url
        } catch ProfileError.sessionExpired {
            // AppRouter đã tự đưa về màn đăng nhập và báo hết phiên, không cần báo thêm.
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? ProfileError.unknown.errorDescription
        }
    }
}
