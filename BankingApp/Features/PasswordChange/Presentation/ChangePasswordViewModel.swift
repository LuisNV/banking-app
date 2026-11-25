import Factory
import Foundation
import Observation

/// Luồng đổi mật khẩu 2 bước: nhập mật khẩu → xác minh mã gửi tới email → xong.
@MainActor
@Observable
final class ChangePasswordViewModel {
    enum Step: Equatable {
        case form, verify, done
    }

    /// Dự phòng khi server không trả `resendAvailableAt`.
    static let resendCooldown = 45

    private(set) var step: Step = .form
    private(set) var isLoading = false
    var alertMessage: String?

    var isShowingAlert: Bool {
        get { alertMessage != nil }
        set { if !newValue { alertMessage = nil } }
    }

    // MARK: Bước 1
    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""
    var isCurrentRevealed = false
    var isNewRevealed = false
    var logoutOtherDevices = true
    private(set) var hasTriedSubmit = false
    /// Lỗi server gắn vào ô (vd. sai mật khẩu hiện tại).
    private(set) var serverFieldErrors: [PasswordChangeField: String] = [:]
    /// Bị khoá đổi mật khẩu (sai 5 lần) tới lúc này.
    private(set) var lockedUntil: Date?

    // MARK: Bước 2
    private(set) var request: PasswordChangeRequest?
    private(set) var code = ""
    private(set) var codeError: String?
    private(set) var resendSecondsLeft = 0

    // MARK: Xong
    private(set) var result: PasswordChangeResult?

    private let useCase: ChangePasswordUseCaseProtocol
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void
    private var countdownTask: Task<Void, Never>?
    private var unlockTask: Task<Void, Never>?

    init(
        useCase: ChangePasswordUseCaseProtocol = Container.shared.changePasswordUseCase(),
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.useCase = useCase
        self.now = now
        self.sleep = sleep
    }

    // MARK: - Bước 1

    var passwordEvaluation: PasswordEvaluation {
        PasswordEvaluation.evaluate(newPassword)
    }

    var isDifferentFromCurrent: Bool {
        !newPassword.isEmpty && newPassword != currentPassword
    }

    var isLocked: Bool {
        guard let lockedUntil else { return false }
        return lockedUntil > now()
    }

    private var localErrors: [PasswordChangeField: String] {
        PasswordChangeValidator.errors(current: currentPassword, new: newPassword, confirm: confirmPassword)
    }

    /// Lỗi hiện dưới ô: lỗi server ưu tiên; lỗi "chưa nhập" chỉ hiện sau khi bấm Tiếp tục.
    func error(for field: PasswordChangeField) -> String? {
        if let serverError = serverFieldErrors[field] { return serverError }
        guard let message = localErrors[field] else { return nil }
        switch field {
        case .current: return hasTriedSubmit ? message : nil
        case .new:
            // Độ mạnh đã có danh sách yêu cầu: chỉ báo chữ khi đã bấm, hoặc lỗi quá dài / trùng mật khẩu cũ.
            if hasTriedSubmit { return message }
            let tooLong = newPassword.utf8.count > PasswordChangeValidator.maxBytes
            return tooLong || (!newPassword.isEmpty && newPassword == currentPassword) ? message : nil
        case .confirm: return confirmPassword.isEmpty && !hasTriedSubmit ? nil : message
        }
    }

    func status(for field: PasswordChangeField) -> FormFieldRow.Status {
        if error(for: field) != nil { return .invalid }
        if field == .confirm, !confirmPassword.isEmpty, confirmPassword == newPassword { return .valid }
        return .none
    }

    /// Người dùng sửa ô nào thì bỏ lỗi server của ô đó.
    func didEdit(_ field: PasswordChangeField) {
        // Đang bị khoá thì giữ thông báo khoá ở ô mật khẩu hiện tại.
        if field == .current, isLocked { return }
        serverFieldErrors[field] = nil
    }

    var canSubmit: Bool {
        !isLoading && !isLocked && localErrors.isEmpty
    }

    /// Bấm "Tiếp tục": server kiểm tra mật khẩu và gửi mã tới email.
    func submit() async {
        hasTriedSubmit = true
        guard canSubmit else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let request = try await useCase.start(
                currentPassword: currentPassword,
                newPassword: newPassword,
                confirmPassword: confirmPassword,
                logoutOtherDevices: logoutOtherDevices
            )
            self.request = request
            code = ""
            codeError = nil
            startCountdown(until: request.resendAvailableAt)
            step = .verify
        } catch {
            handleFormError(PasswordChangeRepositoryImpl.map(error))
        }
    }

    private func handleFormError(_ error: PasswordChangeError) {
        switch error {
        case .invalid(let errors):
            serverFieldErrors.merge(errors) { _, new in new }
        case .wrongCurrentPassword:
            currentPassword = ""
            serverFieldErrors[.current] = error.errorDescription
        case .locked:
            currentPassword = ""
            serverFieldErrors[.current] = error.errorDescription
            if let minutes = error.lockMinutes {
                lock(until: now().addingTimeInterval(TimeInterval(minutes * 60)))
            }
        case .passwordMismatch:
            serverFieldErrors[.confirm] = error.errorDescription
        case .weakPassword, .sameAsCurrent:
            serverFieldErrors[.new] = error.errorDescription
        case .sessionExpired:
            break // AppRouter đã đưa về màn đăng nhập.
        default:
            alertMessage = error.errorDescription
        }
    }

    // MARK: - Bước 2

    var email: String { request?.email ?? "email của bạn" }

    var canVerify: Bool {
        code.count == ChangePasswordUseCase.codeLength && !isLoading
    }

    func updateCode(_ newValue: String) {
        code = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(ChangePasswordUseCase.codeLength))
        if !code.isEmpty { codeError = nil }
    }

    func verify() async {
        guard canVerify, let request else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            result = try await useCase.verify(requestId: request.id, code: code)
            stopCountdown()
            step = .done
        } catch {
            code = ""
            handleVerifyError(PasswordChangeRepositoryImpl.map(error))
        }
    }

    var canResend: Bool {
        resendSecondsLeft == 0 && !isLoading
    }

    var resendTitle: String {
        guard resendSecondsLeft > 0 else { return "Gửi lại mã" }
        return String(format: "Gửi lại sau %d:%02d", resendSecondsLeft / 60, resendSecondsLeft % 60)
    }

    var codeValidityText: String {
        guard let expiresAt = request?.otpExpiresAt else { return "Mã có hiệu lực 10 phút." }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm"
        return "Mã có hiệu lực đến \(formatter.string(from: expiresAt))."
    }

    func resendCode() async {
        guard canResend, let current = request else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let updated = try await useCase.resendCode(requestId: current.id)
            if let updated {
                request = PasswordChangeRequest(
                    id: updated.id,
                    email: updated.email ?? current.email,
                    logoutOtherDevices: current.logoutOtherDevices,
                    otpExpiresAt: updated.otpExpiresAt ?? current.otpExpiresAt,
                    resendAvailableAt: updated.resendAvailableAt,
                    remainingAttempts: updated.remainingAttempts,
                    expiresAt: updated.expiresAt ?? current.expiresAt
                )
            }
            code = ""
            codeError = nil
            startCountdown(until: updated?.resendAvailableAt)
        } catch {
            handleVerifyError(PasswordChangeRepositoryImpl.map(error))
        }
    }

    private func handleVerifyError(_ error: PasswordChangeError) {
        if error.requiresRestart {
            backToForm()
            alertMessage = error.errorDescription
            return
        }
        switch error {
        case .invalidCode, .codeExpired, .tooManyAttempts, .resendTooSoon:
            codeError = error.errorDescription
        case .sessionExpired:
            break
        default:
            alertMessage = error.errorDescription
        }
    }

    /// Quay lại bước 1 (giữ mật khẩu đã nhập, bấm Tiếp tục sẽ tạo yêu cầu mới và mã mới).
    func backToForm() {
        stopCountdown()
        request = nil
        code = ""
        codeError = nil
        step = .form
    }

    // MARK: - Đếm ngược & khoá

    private func startCountdown(until date: Date?) {
        countdownTask?.cancel()
        let availableAt = date ?? now().addingTimeInterval(TimeInterval(Self.resendCooldown))
        resendSecondsLeft = Self.seconds(until: availableAt, now: now())
        guard resendSecondsLeft > 0 else { return }
        let sleep = sleep
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await sleep(.seconds(1)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.resendSecondsLeft = Self.seconds(until: availableAt, now: self.now())
                if self.resendSecondsLeft == 0 { return }
            }
        }
    }

    private func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        resendSecondsLeft = 0
    }

    private func lock(until date: Date) {
        lockedUntil = date
        unlockTask?.cancel()
        let delay = date.timeIntervalSince(now())
        let sleep = sleep
        unlockTask = Task { [weak self] in
            do { try await sleep(.seconds(max(0, delay))) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.lockedUntil = nil
            self.serverFieldErrors[.current] = nil
        }
    }

    private static func seconds(until date: Date, now: Date) -> Int {
        max(0, Int(date.timeIntervalSince(now).rounded(.up)))
    }
}
