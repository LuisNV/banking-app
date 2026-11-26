import Factory
import Foundation
import Observation

/// Điều khiển cả luồng đăng ký 4 bước. Một ViewModel cho cả luồng để dữ liệu
/// (registrationId, email, mật khẩu...) đi xuyên suốt các bước.
///
/// API: `POST /registrations` → `/initiate` → `/verify` → `/complete`, khoá phiên là `registrationId`.
@MainActor
@Observable
final class RegisterViewModel {
    enum Step: Int, CaseIterable {
        case info, password, verify, done

        /// Số bước có đánh số ("1 / 3"); màn hoàn tất không tính.
        static let numberedCount = 3

        /// `nil` ở màn hoàn tất.
        var number: Int? { self == .done ? nil : rawValue + 1 }
    }

    /// Dự phòng khi server không trả `resendAvailableAt`.
    static let resendCooldown = 45

    private(set) var step: Step = .info
    /// Dùng để chọn hướng hiệu ứng chuyển màn (tiến: từ phải sang, lùi: từ trái sang).
    private(set) var isNavigatingBack = false
    private(set) var isLoading = false
    /// Đang kiểm tra phiên dở dang khi mở màn đăng ký.
    private(set) var isResuming = false
    private(set) var errorTitle = RegisterViewModel.defaultErrorTitle
    var errorMessage: String?

    static let defaultErrorTitle = "Không thể tiếp tục"
    static let invalidInfoTitle = "Kiểm tra lại thông tin"
    static let invalidInfoMessage = "Thông tin chưa hợp lệ. Vui lòng kiểm tra các ô được đánh dấu."
    static let restartTitle = "Bắt đầu lại"

    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    // MARK: Phiên
    /// `registrationId` của phiên hiện tại.
    private(set) var registrationId: String?
    /// Thông tin (đã chuẩn hoá) đã gửi khi tạo phiên; sửa khác đi thì phải tạo phiên mới.
    private var submittedInfo: RegistrationInfo?

    // MARK: Bước 1 · Thông tin
    var fullName = ""
    var email = ""
    var phone = ""
    var birthDate: Date
    private(set) var didSubmitInfo = false
    /// Lỗi server gắn vào trường (email/số điện thoại đã có người dùng).
    private(set) var serverFieldErrors: [RegistrationField: String] = [:]

    // MARK: Bước 2 · Mật khẩu
    var password = ""
    var confirmPassword = ""
    var isPasswordVisible = false
    let biometricType: BiometricType
    var biometricEnabled: Bool

    // MARK: Bước 3 · Xác minh
    private(set) var code = ""
    private(set) var resendSecondsLeft = 0
    private(set) var otp: RegistrationOTP?

    // Đổi email (bottom sheet)
    var isShowingChangeEmail = false
    var newEmail = ""
    private(set) var changeEmailError: String?
    private(set) var isChangingEmail = false

    // MARK: Bước 4
    private(set) var authSession: AuthSession?

    // MARK: Dependencies
    private let registerUseCase: RegisterUseCaseProtocol
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void
    private let onCancel: () -> Void
    private let onFinished: (AuthSession) -> Void
    private var countdownTask: Task<Void, Never>?

    /// - Parameters:
    ///   - onCancel: người dùng thoát luồng (bấm quay lại ở bước 1, hoặc "Đăng nhập").
    ///   - onFinished: đăng ký xong và đã đăng nhập (server trả token), vào thẳng app.
    init(
        registerUseCase: RegisterUseCaseProtocol = Container.shared.registerUseCase(),
        biometricType: BiometricType = Container.shared.biometricAuthService().availableType,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        onCancel: @escaping () -> Void,
        onFinished: @escaping (AuthSession) -> Void
    ) {
        self.registerUseCase = registerUseCase
        self.biometricType = biometricType
        self.biometricEnabled = biometricType != .none
        self.now = now
        self.sleep = sleep
        self.onCancel = onCancel
        self.onFinished = onFinished
        self.birthDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? now()
    }

    // MARK: - Mở lại giữa chừng

    /// Gọi khi màn đăng ký xuất hiện: còn phiên dở dang trên máy thì đưa về đúng bước.
    func resumeIfNeeded() async {
        guard registrationId == nil, step == .info, !isResuming else { return }
        isResuming = true
        defer { isResuming = false }
        guard let resumed = await registerUseCase.resume() else { return }

        let info = resumed.saved.info
        fullName = info.fullName
        email = resumed.session.email ?? info.email
        phone = info.phone
        birthDate = info.birthDate
        registrationId = resumed.session.id
        submittedInfo = RegistrationInfo(fullName: info.fullName, email: email, phone: info.phone, birthDate: info.birthDate)

        switch resumed.session.nextStep {
        case .setPassword:
            go(to: .password)
        case .verifyEmail:
            apply(otp: resumed.session.otp)
            go(to: .verify)
        case .complete:
            await complete()
        case .completed:
            break
        }
    }

    // MARK: - Bước 1

    var registrationInfo: RegistrationInfo {
        RegistrationInfo(fullName: fullName, email: email, phone: phone, birthDate: birthDate)
    }

    var infoErrors: [RegistrationField: String] {
        RegistrationValidator.errors(for: registrationInfo, now: now()).merging(serverFieldErrors) { local, _ in local }
    }

    /// Các lỗi theo đúng thứ tự trường trên màn hình.
    var infoErrorMessages: [String] {
        let errors = infoErrors
        return RegistrationField.allCases.compactMap { errors[$0] }
    }

    func status(for field: RegistrationField) -> FormFieldStatus {
        if serverFieldErrors[field] != nil { return .invalid }
        let value: String
        switch field {
        case .fullName: value = fullName
        case .email: value = email
        case .phone: value = phone
        case .birthDate: return infoErrors[.birthDate] == nil ? .none : .invalid
        }
        let hasError = infoErrors[field] != nil
        if value.trimmingCharacters(in: .whitespaces).isEmpty {
            return didSubmitInfo && hasError ? .invalid : .none
        }
        if !hasError { return .valid }
        return didSubmitInfo ? .invalid : .none
    }

    /// Người dùng sửa một trường: bỏ lỗi server cũ của trường đó.
    func didEdit(_ field: RegistrationField) {
        serverFieldErrors[field] = nil
    }

    /// Bấm "Tiếp tục" ở bước 1: tạo phiên đăng ký (nếu thông tin đổi so với phiên cũ thì tạo phiên mới).
    func continueFromInfo() async {
        didSubmitInfo = true
        guard RegistrationValidator.errors(for: registrationInfo, now: now()).isEmpty else {
            showError(Self.invalidInfoMessage, title: Self.invalidInfoTitle)
            return
        }
        if registrationId != nil, submittedInfo == registrationInfo.normalized {
            go(to: .password)
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await registerUseCase.start(info: registrationInfo)
            registrationId = session.id
            submittedInfo = registrationInfo.normalized
            go(to: .password)
        } catch RegisterError.emailTaken {
            serverFieldErrors[.email] = RegisterError.emailTaken.errorDescription
            showError(RegisterError.emailTaken.errorDescription ?? "", title: Self.invalidInfoTitle)
        } catch RegisterError.phoneTaken {
            serverFieldErrors[.phone] = RegisterError.phoneTaken.errorDescription
            showError(RegisterError.phoneTaken.errorDescription ?? "", title: Self.invalidInfoTitle)
        } catch {
            showError(Self.message(for: error))
        }
    }

    // MARK: - Bước 2

    var passwordEvaluation: PasswordEvaluation {
        PasswordEvaluation.evaluate(password)
    }

    var confirmStatus: FormFieldStatus {
        if confirmPassword.isEmpty { return .none }
        return confirmPassword == password ? .valid : .invalid
    }

    var canCreateAccount: Bool {
        passwordEvaluation.meetsRequirements && confirmPassword == password && !isLoading
    }

    /// Bấm "Tạo tài khoản" ở bước 2: lưu mật khẩu + Face ID, server gửi mã tới email.
    func createAccount() async {
        guard canCreateAccount, let id = registrationId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await registerUseCase.setPassword(
                id: id, password: password, confirmPassword: confirmPassword, biometricEnabled: biometricEnabled
            )
            if session.nextStep == .complete {
                // Email đã xác minh từ trước (quay lại đổi mật khẩu): hoàn tất luôn.
                await completeAfterLoading()
                return
            }
            code = ""
            if let newOTP = session.otp {
                apply(otp: newOTP)
            } else if otp == nil {
                apply(otp: nil)
            }
            // Còn lại: quay lại bước 2 để đổi mật khẩu, server không gửi mã mới nên giữ đếm ngược cũ.
            go(to: .verify)
        } catch {
            await handle(error)
        }
    }

    // MARK: - Bước 3

    var normalizedEmail: String {
        RegistrationValidator.normalizedEmail(email)
    }

    var canVerify: Bool {
        code.count == RegisterUseCase.codeLength && !isLoading
    }

    /// Chỉ nhận chữ số, tối đa 6 ký tự (kể cả khi dán hoặc tự điền từ Mail).
    func updateCode(_ newValue: String) {
        code = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(RegisterUseCase.codeLength))
    }

    func verify() async {
        guard canVerify, let id = registrationId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await registerUseCase.verify(id: id, code: code)
            stopResendCountdown()
            await completeAfterLoading()
        } catch {
            code = ""
            await handle(error)
        }
    }

    var canResend: Bool {
        resendSecondsLeft == 0 && !isLoading
    }

    var resendTitle: String {
        guard resendSecondsLeft > 0 else { return "Gửi lại mã" }
        return String(format: "Gửi lại sau %d:%02d", resendSecondsLeft / 60, resendSecondsLeft % 60)
    }

    /// Vd. "Mã có hiệu lực đến 10:25." (hoặc 10 phút nếu server không trả giờ hết hạn).
    var codeValidityText: String {
        guard let expiresAt = otp?.expiresAt else { return "Mã có hiệu lực 10 phút." }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm"
        return "Mã có hiệu lực đến \(formatter.string(from: expiresAt))."
    }

    func resendCode() async {
        guard canResend, let id = registrationId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await registerUseCase.resendCode(id: id)
            code = ""
            apply(otp: session.otp)
        } catch {
            await handle(error)
        }
    }

    // MARK: Đổi email

    func showChangeEmail() {
        newEmail = normalizedEmail
        changeEmailError = nil
        isShowingChangeEmail = true
    }

    var canSubmitNewEmail: Bool {
        let email = RegistrationValidator.normalizedEmail(newEmail)
        return RegistrationValidator.isValidEmail(email) && email != normalizedEmail && !isChangingEmail
    }

    func submitNewEmail() async {
        let target = RegistrationValidator.normalizedEmail(newEmail)
        guard RegistrationValidator.isValidEmail(target) else {
            changeEmailError = "Email không hợp lệ."
            return
        }
        guard target != normalizedEmail else {
            changeEmailError = "Email mới trùng với email hiện tại."
            return
        }
        guard let id = registrationId, !isChangingEmail else { return }
        isChangingEmail = true
        defer { isChangingEmail = false }
        changeEmailError = nil

        do {
            let session = try await registerUseCase.changeEmail(id: id, email: target)
            email = session.email ?? target
            submittedInfo?.email = normalizedEmail
            code = ""
            apply(otp: session.otp)
            isShowingChangeEmail = false
        } catch let error as RegisterError where error.requiresRestart {
            isShowingChangeEmail = false
            await handle(error)
        } catch {
            changeEmailError = Self.message(for: error)
        }
    }

    // MARK: - Bước 4

    func finish() {
        guard let authSession else { return }
        onFinished(authSession)
    }

    private func completeAfterLoading() async {
        isLoading = false
        await complete()
    }

    private func complete() async {
        guard let id = registrationId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            authSession = try await registerUseCase.complete(id: id)
            go(to: .done)
        } catch RegisterError.emailTaken, RegisterError.phoneTaken {
            // Có người vừa đăng ký trùng trong lúc chờ: phiên này không hoàn tất được nữa.
            restart(message: "Email hoặc số điện thoại vừa được dùng cho tài khoản khác. Vui lòng kiểm tra lại thông tin.")
        } catch {
            await handle(error)
        }
    }

    // MARK: - Điều hướng

    func goBack() {
        switch step {
        case .info: cancel()
        case .password: go(to: .info, back: true)
        case .verify:
            // Server cho phép quay lại bước 2 để đổi mật khẩu (không gửi thêm mail).
            go(to: .password, back: true)
        case .done: break
        }
    }

    /// Thoát luồng: bỏ phiên đang lưu để lần sau bắt đầu mới.
    func cancel() {
        stopResendCountdown()
        registerUseCase.discard()
        onCancel()
    }

    // MARK: - Private

    /// Xử lý lỗi chung của bước 2–4.
    private func handle(_ error: Error) async {
        guard let registerError = error as? RegisterError else {
            showError(Self.message(for: error))
            return
        }
        switch registerError {
        case .sessionNotFound, .sessionExpired:
            restart(message: registerError.errorDescription ?? "")
        case .wrongStep:
            await syncWithServer()
        case .tooManyAttempts, .codeExpired:
            // Cho phép gửi lại ngay nếu đã hết thời gian chờ.
            showError(Self.message(for: registerError))
        default:
            showError(Self.message(for: registerError))
        }
    }

    /// Phiên không dùng được (1005/1006): quay về bước 1, giữ thông tin đã nhập, tạo phiên mới khi bấm Tiếp tục.
    private func restart(message: String) {
        stopResendCountdown()
        registrationId = nil
        submittedInfo = nil
        code = ""
        otp = nil
        registerUseCase.discard()
        go(to: .info, back: true)
        showError(message, title: Self.restartTitle)
    }

    /// Sai bước (1007): hỏi server phiên đang ở bước nào rồi chuyển tới đó.
    private func syncWithServer() async {
        guard let resumed = await registerUseCase.resume() else {
            restart(message: RegisterError.sessionNotFound.errorDescription ?? "")
            return
        }
        switch resumed.session.nextStep {
        case .setPassword: go(to: .password, back: true)
        case .verifyEmail:
            apply(otp: resumed.session.otp)
            go(to: .verify)
        case .complete: await completeAfterLoading()
        case .completed: restart(message: RegisterError.wrongStep.errorDescription ?? "")
        }
    }

    private func showError(_ message: String, title: String = RegisterViewModel.defaultErrorTitle) {
        errorTitle = title
        errorMessage = message
    }

    private func go(to newStep: Step, back: Bool = false) {
        isNavigatingBack = back
        step = newStep
    }

    /// Cập nhật mã vừa gửi và đếm ngược "Gửi lại sau" theo `resendAvailableAt` của server.
    private func apply(otp newOTP: RegistrationOTP?) {
        if let newOTP { otp = newOTP }
        let availableAt = newOTP?.resendAvailableAt ?? now().addingTimeInterval(TimeInterval(Self.resendCooldown))
        startResendCountdown(until: availableAt)
    }

    private func startResendCountdown(until availableAt: Date) {
        countdownTask?.cancel()
        resendSecondsLeft = Self.seconds(until: availableAt, now: now())
        guard resendSecondsLeft > 0 else { return }
        let sleep = sleep
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await sleep(.seconds(1)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                // Tính lại theo giờ thật để không lệch khi app vào nền.
                self.resendSecondsLeft = Self.seconds(until: availableAt, now: self.now())
                if self.resendSecondsLeft == 0 { return }
            }
        }
    }

    private static func seconds(until date: Date, now: Date) -> Int {
        max(0, Int(date.timeIntervalSince(now).rounded(.up)))
    }

    private func stopResendCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        resendSecondsLeft = 0
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? RegisterError.unknown.errorDescription ?? ""
    }
}
