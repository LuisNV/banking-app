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
    /// Ẩn thanh tab nổi khi tab đang mở một màn con.
    var isTabBarHidden = false
    /// Từ của ngày từ API (có chiết tự). `nil` (lỗi/chưa tải) thì dùng từ trong dashboard.
    private(set) var wordOfTheDay: VocabEntry?
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

    /// Cài đặt học (mục tiêu, nhắc học, chữ Hán) dùng chung cho Trang chủ và tab Cá nhân.
    let learningSettings: LearningSettingsStore

    private let logoutUseCase: LogoutUseCaseProtocol
    private let uploadAvatarUseCase: UploadAvatarUseCaseProtocol
    private let getDashboardUseCase: GetHomeDashboardUseCaseProtocol
    private let getMyProfileUseCase: GetMyProfileUseCaseProtocol
    private let pronunciation: PronunciationServiceProtocol
    private let loadWordOfTheDay: () async throws -> VocabEntry
    private let prepareImage: (Data) -> Data?
    private let onLoggedOut: () -> Void

    init(
        user: User?,
        logoutUseCase: LogoutUseCaseProtocol = Container.shared.logoutUseCase(),
        uploadAvatarUseCase: UploadAvatarUseCaseProtocol = Container.shared.uploadAvatarUseCase(),
        getDashboardUseCase: GetHomeDashboardUseCaseProtocol = Container.shared.getHomeDashboardUseCase(),
        getMyProfileUseCase: GetMyProfileUseCaseProtocol = Container.shared.getMyProfileUseCase(),
        pronunciation: PronunciationServiceProtocol = Container.shared.pronunciationService(),
        loadWordOfTheDay: (() async throws -> VocabEntry)? = nil,
        prepareImage: @escaping (Data) -> Data? = AvatarImageProcessor.jpegData(from:),
        today: Date = Date(),
        learningSettings: LearningSettingsStore? = nil,
        onLoggedOut: @escaping () -> Void
    ) {
        self.user = user
        self.learningSettings = learningSettings ?? LearningSettingsStore()
        self.logoutUseCase = logoutUseCase
        self.uploadAvatarUseCase = uploadAvatarUseCase
        self.getDashboardUseCase = getDashboardUseCase
        self.getMyProfileUseCase = getMyProfileUseCase
        self.pronunciation = pronunciation
        self.loadWordOfTheDay = loadWordOfTheDay ?? { try await Container.shared.vocabularyRepository().wordOfTheDay() }
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

    /// Tải dashboard và Từ của ngày. `force`: tải lại (kéo để làm mới); lỗi thì giữ dữ liệu đang hiện.
    func loadDashboard(force: Bool = false) async {
        guard force || dashboard == nil, !isLoadingDashboard else { return }
        isLoadingDashboard = true
        defer { isLoadingDashboard = false }
        async let dashboardResult = try? getDashboardUseCase.execute()
        async let wordResult = try? loadWordOfTheDay()
        if let newDashboard = await dashboardResult { dashboard = newDashboard }
        if let newWord = await wordResult { wordOfTheDay = newWord }
    }

    /// Kéo để làm mới Trang chủ: tải lại mọi thứ màn này đã gọi (dashboard, Từ của ngày,
    /// hồ sơ cho lời chào/ảnh đại diện, cài đặt học cho mục tiêu mỗi ngày).
    func refreshHome() async {
        async let dashboardDone: Void = loadDashboard(force: true)
        async let profileDone: Void = loadProfile(force: true)
        async let settingsDone: Void = learningSettings.load(force: true)
        _ = await (dashboardDone, profileDone, settingsDone)
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

    /// Sau khi sửa hồ sơ thành công: hiện ngay dữ liệu mới server trả về.
    func applyUpdatedProfile(_ profile: UserProfile) {
        self.profile = profile
        profileErrorMessage = nil
    }

    /// Mục tiêu hôm nay: số phút đã học (từ dashboard) trên mục tiêu người dùng đã đặt.
    var dailyGoal: DailyGoal? {
        guard let studied = dashboard?.dailyGoal.studiedMinutes else { return nil }
        return DailyGoal(studiedMinutes: studied, targetMinutes: learningSettings.settings.dailyGoalMinutes)
    }

    func playWordOfTheDay() {
        if let word = wordOfTheDay?.word {
            pronunciation.play(url: word.audioURL, fallbackText: word.hanzi, slow: false)
        } else if let word = dashboard?.wordOfTheDay {
            pronunciation.speak(word.hanzi)
        }
    }

    func logout() async {
        isLoggingOut = true
        await logoutUseCase.execute()
        await learningSettings.signOut()
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
