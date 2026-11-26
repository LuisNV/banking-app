import Factory
import Foundation
import Observation

/// Quên mật khẩu: nhập email/SĐT → nhập mã → đặt mật khẩu mới → xong.
@MainActor
@Observable
final class ForgotPasswordViewModel {
    enum Step: Int, Equatable {
        case identifier = 1, verify, newPassword, done
    }

    static let resendCooldown = 45

    private(set) var step: Step = .identifier
    private(set) var isLoading = false
    var alertMessage: String?

    var isShowingAlert: Bool {
        get { alertMessage != nil }
        set { if !newValue { alertMessage = nil } }
    }

    // MARK: Bước 1
    var identifier = ""
    private(set) var identifierError: String?

    // MARK: Bước 2
    private(set) var request: PasswordResetRequest?
    private(set) var code = ""
    private(set) var codeError: String?
    /// Mã cũ không dùng được nữa (hết hạn / sai quá 5 lần): làm nổi nút "Gửi lại mã".
    private(set) var needsNewCode = false
    private(set) var resendSecondsLeft = 0
    private var verification: PasswordResetVerification?
    /// Mã đã xác minh đúng, để lấy lại token khi gặp 1024 (mã còn hạn).
    private var verifiedCode: String?

    // MARK: Bước 3
    var newPassword = ""
    var confirmPassword = ""
    var isPasswordRevealed = false
    private(set) var hasTriedSubmit = false
    private(set) var serverFieldErrors: [PasswordResetField: String] = [:]

    // MARK: Xong
    private(set) var result: PasswordResetResult?

    private let useCase: ResetPasswordUseCaseProtocol
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void
    private var countdownTask: Task<Void, Never>?

    init(
        useCase: ResetPasswordUseCaseProtocol = Container.shared.resetPasswordUseCase(),
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.useCase = useCase
        self.now = now
        self.sleep = sleep
    }

    /// Điền sẵn email/SĐT (từ màn đăng nhập hoặc tài khoản đang đăng nhập).
    func prefill(_ value: String?) {
        guard identifier.isEmpty, let value, !value.isEmpty else { return }
        identifier = value
    }

    // MARK: - Bước 1

    var canSendCode: Bool {
        !identifier.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    func didEditIdentifier() {
        identifierError = nil
    }

    func sendCode() async {
        guard canSendCode else { return }
        guard PasswordResetValidator.isValidIdentifier(identifier) else {
            identifierError = PasswordResetError.invalidIdentifier(message: nil).errorDescription
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let request = try await useCase.start(identifier: identifier)
            self.request = request
            verification = nil
            verifiedCode = nil
            code = ""
            codeError = nil
            needsNewCode = false
            startCountdown(until: request.resendAvailableAt)
            step = .verify
        } catch {
            let mapped = PasswordResetRepositoryImpl.map(error, in: .start)
            switch mapped {
            case .invalidIdentifier: identifierError = mapped.errorDescription
            default: alertMessage = mapped.errorDescription
            }
        }
    }

    // MARK: - Bước 2

    /// Email nhận mã (đã che), vd. "th••••@example.com".
    var destination: String { request?.destination ?? "email của bạn" }

    var canVerify: Bool {
        code.count == ResetPasswordUseCase.codeLength && !isLoading
    }

    func updateCode(_ newValue: String) {
        code = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(ResetPasswordUseCase.codeLength))
        if !code.isEmpty { codeError = nil }
    }

    func verify() async {
        guard canVerify, let request else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            verification = try await useCase.verify(resetId: request.id, code: code)
            verifiedCode = code
            stopCountdown()
            step = .newPassword
        } catch {
            code = ""
            handleCodeError(PasswordResetRepositoryImpl.map(error, in: .verify))
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
            if let updated = try await useCase.resendCode(resetId: current.id) {
                request = PasswordResetRequest(
                    id: updated.id,
                    identifierType: updated.identifierType ?? current.identifierType,
                    destination: updated.destination ?? current.destination,
                    otpExpiresAt: updated.otpExpiresAt ?? current.otpExpiresAt,
                    resendAvailableAt: updated.resendAvailableAt,
                    remainingAttempts: updated.remainingAttempts,
                    expiresAt: updated.expiresAt ?? current.expiresAt
                )
                startCountdown(until: updated.resendAvailableAt)
            } else {
                startCountdown(until: nil)
            }
            code = ""
            codeError = nil
            needsNewCode = false
        } catch {
            handleCodeError(PasswordResetRepositoryImpl.map(error, in: .resend))
        }
    }

    private func handleCodeError(_ error: PasswordResetError) {
        if error.requiresRestart {
            restart(message: error.errorDescription)
            return
        }
        switch error {
        case .alreadyVerified where verification != nil:
            step = .newPassword
        case .invalidCode, .codeExpired, .tooManyAttempts, .resendTooSoon, .alreadyVerified:
            codeError = error.errorDescription
            if error.needsNewCode { needsNewCode = true }
        default:
            alertMessage = error.errorDescription
        }
    }

    // MARK: - Bước 3

    var passwordEvaluation: PasswordEvaluation {
        PasswordEvaluation.evaluate(newPassword)
    }

    func error(for field: PasswordResetField) -> String? {
        if let serverError = serverFieldErrors[field] { return serverError }
        let errors = PasswordResetValidator.errors(new: newPassword, confirm: confirmPassword)
        guard let message = errors[field] else { return nil }
        if hasTriedSubmit { return message }
        // Chưa bấm: chỉ báo "quá dài" và "chưa khớp" (khi đã gõ ô nhập lại).
        switch field {
        case .new: return newPassword.utf8.count > PasswordResetValidator.maxBytes ? message : nil
        case .confirm: return confirmPassword.isEmpty ? nil : message
        }
    }

    func status(for field: PasswordResetField) -> FormFieldRow.Status {
        if error(for: field) != nil { return .invalid }
        if field == .confirm, !confirmPassword.isEmpty, confirmPassword == newPassword { return .valid }
        return .none
    }

    func didEdit(_ field: PasswordResetField) {
        serverFieldErrors[field] = nil
    }

    func complete() async {
        hasTriedSubmit = true
        guard !isLoading, PasswordResetValidator.errors(new: newPassword, confirm: confirmPassword).isEmpty,
              let request, let verification else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            result = try await submit(resetId: request.id, token: verification.token)
            step = .done
        } catch let error as PasswordResetError where error == .tokenInvalid {
            // 1024: lấy token mới bằng mã cũ (nếu còn hạn) rồi thử lại một lần.
            await retryWithFreshToken(resetId: request.id)
        } catch {
            handleCompleteError(PasswordResetRepositoryImpl.map(error, in: .complete))
        }
    }

    private func submit(resetId: String, token: String) async throws -> PasswordResetResult {
        do {
            return try await useCase.complete(
                resetId: resetId, token: token, newPassword: newPassword, confirmPassword: confirmPassword
            )
        } catch {
            throw PasswordResetRepositoryImpl.map(error, in: .complete)
        }
    }

    private func retryWithFreshToken(resetId: String) async {
        let codeStillValid = request?.otpExpiresAt.map { $0 > now() } ?? false
        guard let verifiedCode, codeStillValid else {
            backToVerify(message: PasswordResetError.tokenInvalid.errorDescription)
            return
        }
        do {
            let fresh = try await useCase.verify(resetId: resetId, code: verifiedCode)
            verification = fresh
            result = try await submit(resetId: resetId, token: fresh.token)
            step = .done
        } catch {
            let mapped = PasswordResetRepositoryImpl.map(error, in: .complete)
            if mapped == .tokenInvalid {
                backToVerify(message: mapped.errorDescription)
            } else {
                handleCompleteError(mapped)
            }
        }
    }

    private func handleCompleteError(_ error: PasswordResetError) {
        if error.requiresRestart {
            restart(message: error.errorDescription)
            return
        }
        switch error {
        case .invalidPassword(let errors):
            serverFieldErrors.merge(errors) { _, new in new }
        case .weakPassword, .sameAsCurrent:
            serverFieldErrors[.new] = error.errorDescription
        case .passwordMismatch:
            serverFieldErrors[.confirm] = error.errorDescription
        case .notVerified, .tokenInvalid:
            backToVerify(message: error.errorDescription)
        default:
            alertMessage = error.errorDescription
        }
    }

    // MARK: - Điều hướng

    /// Nút quay lại ở thanh trên.
    func goBack() {
        switch step {
        case .verify: restart(message: nil)
        case .newPassword: step = .verify
        case .identifier, .done: break
        }
    }

    /// Về bước 1, giữ email/SĐT đã nhập.
    private func restart(message: String?) {
        stopCountdown()
        request = nil
        verification = nil
        verifiedCode = nil
        code = ""
        codeError = nil
        needsNewCode = false
        step = .identifier
        if let message { alertMessage = message }
    }

    private func backToVerify(message: String?) {
        verification = nil
        verifiedCode = nil
        code = ""
        codeError = message
        step = .verify
    }

    // MARK: - Đếm ngược

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

    private static func seconds(until date: Date, now: Date) -> Int {
        max(0, Int(date.timeIntervalSince(now).rounded(.up)))
    }
}
