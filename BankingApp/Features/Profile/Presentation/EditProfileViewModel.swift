import Factory
import Foundation
import Observation

/// Form sửa hồ sơ. Đổi email thì hỏi mật khẩu hiện tại trong bottom sheet.
@MainActor
@Observable
final class EditProfileViewModel {
    // MARK: Form
    var fullName: String
    var phone: String
    var address: String
    var gender: UserProfile.Gender?
    var birthDate: Date?
    var email: String

    // MARK: Bottom sheet mật khẩu
    var isShowingPasswordSheet = false
    var currentPassword = ""
    var isPasswordRevealed = false
    private(set) var passwordError: String?
    /// Bị khoá nhập mật khẩu (1018) tới lúc này: chưa hết hạn thì không gửi lên server.
    private(set) var passwordLockedUntil: Date?
    private var unlockTask: Task<Void, Never>?

    // MARK: Trạng thái
    private(set) var isSaving = false
    /// Lỗi từ server gắn vào từng trường (vd. email/số điện thoại trùng).
    private(set) var serverFieldErrors: [ProfileField: String] = [:]
    /// Đã bấm Lưu ít nhất một lần: từ đó mới hiện lỗi chưa nhập.
    private(set) var hasTriedSaving = false
    /// Lưu thành công: màn hình tự đóng.
    private(set) var didSave = false
    var alertMessage: String?

    var isShowingAlert: Bool {
        get { alertMessage != nil }
        set { if !newValue { alertMessage = nil } }
    }

    let original: UserProfile
    private let updateUseCase: UpdateProfileUseCaseProtocol
    private let now: () -> Date
    private let onSaved: (UserProfile) -> Void
    private let onAccountGone: () -> Void

    init(
        profile: UserProfile,
        updateUseCase: UpdateProfileUseCaseProtocol = Container.shared.updateProfileUseCase(),
        now: @escaping () -> Date = Date.init,
        onSaved: @escaping (UserProfile) -> Void,
        onAccountGone: @escaping () -> Void = {}
    ) {
        original = profile
        fullName = profile.fullName
        phone = profile.phone ?? ""
        address = profile.address ?? ""
        gender = profile.gender
        birthDate = profile.birthDate
        email = profile.email ?? ""
        self.updateUseCase = updateUseCase
        self.now = now
        self.onSaved = onSaved
        self.onAccountGone = onAccountGone
    }

    // MARK: Derived

    private var draft: ProfileUpdate {
        ProfileUpdate(
            fullName: fullName,
            phone: phone,
            address: address,
            gender: gender,
            birthDate: birthDate,
            // Ô email để trống và tài khoản vốn chưa có email → không gửi email.
            email: email.isEmpty && original.email == nil ? nil : email,
            currentPassword: nil
        )
    }

    var isChangingEmail: Bool {
        ProfileUpdateValidator.isChangingEmail(draft.email, current: original.email)
    }

    /// Email mới đã chuẩn hoá (hiện trong bottom sheet).
    var newEmail: String { ProfileUpdateValidator.normalizedEmail(email) }

    var hasChanges: Bool {
        let value = ProfileUpdateValidator.normalized(draft)
        return value.fullName != original.fullName
            || value.phone != (original.phone ?? "")
            || value.address != (original.address ?? "")
            || value.gender != original.gender
            || !Self.sameDay(value.birthDate, original.birthDate)
            || isChangingEmail
    }

    var canSave: Bool { hasChanges && !isSaving }

    /// Lỗi hiện dưới trường: lỗi server ưu tiên, sau đó lỗi kiểm tra phía app.
    func error(for field: ProfileField) -> String? {
        if let serverError = serverFieldErrors[field] { return serverError }
        let errors = ProfileUpdateValidator.errors(for: draft, now: now())
        guard let message = errors[field] else { return nil }
        // Lỗi "chưa nhập" chỉ hiện sau khi bấm Lưu; lỗi định dạng/độ dài hiện ngay.
        let isEmpty = ProfileUpdateValidator.trimmed(value(of: field)).isEmpty
        return hasTriedSaving || !isEmpty ? message : nil
    }

    func status(for field: ProfileField) -> FormFieldRow.Status {
        error(for: field) == nil ? .none : .invalid
    }

    /// Người dùng sửa một trường: bỏ lỗi server cũ của trường đó.
    func didEdit(_ field: ProfileField) {
        serverFieldErrors[field] = nil
    }

    // MARK: Actions

    /// Bấm "Lưu".
    func save() async {
        hasTriedSaving = true
        let errors = ProfileUpdateValidator.errors(for: draft, now: now())
        guard errors.isEmpty else { return }
        if isChangingEmail {
            currentPassword = ""
            if !isPasswordLocked { passwordError = nil }
            isShowingPasswordSheet = true
            return
        }
        await submit(password: nil)
    }

    var isPasswordLocked: Bool {
        guard let passwordLockedUntil else { return false }
        return passwordLockedUntil > now()
    }

    var canConfirmPassword: Bool {
        !isSaving && !isPasswordLocked && !currentPassword.isEmpty
    }

    /// Bấm "Xác nhận" trong bottom sheet.
    func confirmPassword() async {
        guard !isPasswordLocked else { return }
        guard !currentPassword.isEmpty else {
            passwordError = ProfileUpdateError.passwordRequired.errorDescription
            return
        }
        await submit(password: currentPassword)
    }

    func cancelPassword() {
        isShowingPasswordSheet = false
        currentPassword = ""
        // Đang bị khoá thì giữ thông báo để mở lại sheet vẫn thấy.
        if !isPasswordLocked { passwordError = nil }
    }

    private func submit(password: String?) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        passwordError = nil

        var update = draft
        update.currentPassword = password
        do {
            let profile = try await updateUseCase.execute(update, currentEmail: original.email)
            isShowingPasswordSheet = false
            currentPassword = ""
            clearPasswordLock()
            didSave = true
            onSaved(profile)
        } catch let error as ProfileUpdateError {
            handle(error)
        } catch {
            alertMessage = ProfileUpdateError.unknown.errorDescription
        }
    }

    private func handle(_ error: ProfileUpdateError) {
        switch error {
        case .invalid(let errors):
            serverFieldErrors.merge(errors) { _, new in new }
            isShowingPasswordSheet = false
        case .passwordRequired:
            passwordError = error.errorDescription
            isShowingPasswordSheet = true
        case .wrongPassword:
            // Giữ sheet mở để nhập lại; câu lỗi của server có "Bạn còn N lần thử".
            passwordError = error.errorDescription
            currentPassword = ""
        case .passwordLocked:
            // Đang bị khoá: kể cả mật khẩu đúng cũng bị từ chối, nên khoá nút Xác nhận tới khi hết hạn.
            passwordError = error.errorDescription
            currentPassword = ""
            isShowingPasswordSheet = true
            if let minutes = error.lockMinutes {
                lockPassword(until: now().addingTimeInterval(TimeInterval(minutes * 60)))
            }
        case .emailTaken:
            isShowingPasswordSheet = false
            serverFieldErrors[.email] = error.errorDescription
        case .phoneTaken:
            isShowingPasswordSheet = false
            serverFieldErrors[.phone] = error.errorDescription
        case .sessionExpired:
            // AppRouter đã đưa về màn đăng nhập.
            isShowingPasswordSheet = false
        case .accountNotFound:
            isShowingPasswordSheet = false
            onAccountGone()
        case .network, .api, .unknown:
            if isShowingPasswordSheet {
                passwordError = error.errorDescription
            } else {
                alertMessage = error.errorDescription
            }
        }
    }

    private func lockPassword(until date: Date) {
        passwordLockedUntil = date
        unlockTask?.cancel()
        let delay = date.timeIntervalSince(now())
        unlockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, delay)))
            guard !Task.isCancelled else { return }
            self?.clearPasswordLock()
        }
    }

    /// Hết thời gian khoá (hoặc đổi thành công): cho nhập lại.
    private func clearPasswordLock() {
        unlockTask?.cancel()
        unlockTask = nil
        guard passwordLockedUntil != nil else { return }
        passwordLockedUntil = nil
        passwordError = nil
    }

    private func value(of field: ProfileField) -> String {
        switch field {
        case .fullName: return fullName
        case .phone: return phone
        case .address: return address
        case .email: return email
        case .birthDate: return birthDate == nil ? "" : "x"
        }
    }

    private static func sameDay(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (lhs?, rhs?): return Calendar.current.isDate(lhs, inSameDayAs: rhs)
        default: return false
        }
    }
}
