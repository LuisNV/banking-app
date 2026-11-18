import Factory
import Foundation
import Observation

/// Điều khiển cả luồng đăng ký 4 bước. Một ViewModel cho cả luồng để dữ liệu
/// (email, mật khẩu...) đi xuyên suốt các bước mà không phải truyền qua lại.
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

    static let resendCooldown = 45

    private(set) var step: Step = .info
    /// Dùng để chọn hướng hiệu ứng chuyển màn (tiến: từ phải sang, lùi: từ trái sang).
    private(set) var isNavigatingBack = false
    private(set) var isLoading = false
    private(set) var errorTitle = RegisterViewModel.defaultErrorTitle
    var errorMessage: String?

    static let defaultErrorTitle = "Không thể tiếp tục"
    static let invalidInfoTitle = "Kiểm tra lại thông tin"

    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    // MARK: Bước 1 · Thông tin
    var fullName = ""
    var email = ""
    var phone = ""
    var birthDate: Date
    private(set) var didSubmitInfo = false

    // MARK: Bước 2 · Mật khẩu
    var password = ""
    var confirmPassword = ""
    var isPasswordVisible = false

    // MARK: Bước 3 · Xác minh
    private(set) var code = ""
    private(set) var resendSecondsLeft = 0

    // MARK: Dependencies
    private let registerUseCase: RegisterUseCaseProtocol
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void
    private let onCancel: () -> Void
    private let onFinished: (String) -> Void
    private var countdownTask: Task<Void, Never>?

    /// - Parameters:
    ///   - onCancel: người dùng thoát luồng (bấm quay lại ở bước 1, hoặc "Đăng nhập").
    ///   - onFinished: đăng ký xong, nhận email đã xác minh để điền sẵn ở màn đăng nhập.
    init(
        registerUseCase: RegisterUseCaseProtocol = Container.shared.registerUseCase(),
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        onCancel: @escaping () -> Void,
        onFinished: @escaping (String) -> Void
    ) {
        self.registerUseCase = registerUseCase
        self.now = now
        self.sleep = sleep
        self.onCancel = onCancel
        self.onFinished = onFinished
        self.birthDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? now()
    }

    // MARK: - Bước 1

    var registrationInfo: RegistrationInfo {
        RegistrationInfo(fullName: fullName, email: email, phone: phone, birthDate: birthDate)
    }

    var infoErrors: [RegistrationField: String] {
        RegistrationValidator.errors(for: registrationInfo, now: now())
    }

    /// Các lỗi theo đúng thứ tự trường trên màn hình.
    var infoErrorMessages: [String] {
        let errors = infoErrors
        return RegistrationField.allCases.compactMap { errors[$0] }
    }

    func status(for field: RegistrationField) -> FormFieldRow.Status {
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

    /// Thông tin chưa hợp lệ → hiện popup liệt kê lỗi (ô sai vẫn có dấu đỏ để dễ tìm).
    func continueFromInfo() {
        didSubmitInfo = true
        let messages = infoErrorMessages
        guard messages.isEmpty else {
            showError(messages.joined(separator: "\n"), title: Self.invalidInfoTitle)
            return
        }
        go(to: .password)
    }

    // MARK: - Bước 2

    var passwordEvaluation: PasswordEvaluation {
        PasswordEvaluation.evaluate(password)
    }

    var confirmStatus: FormFieldRow.Status {
        if confirmPassword.isEmpty { return .none }
        return confirmPassword == password ? .valid : .invalid
    }

    var canCreateAccount: Bool {
        passwordEvaluation.meetsRequirements && confirmPassword == password && !isLoading
    }

    func createAccount() async {
        guard canCreateAccount else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await registerUseCase.createAccount(info: registrationInfo, password: password)
            code = ""
            go(to: .verify)
            startResendCountdown()
        } catch {
            showError(Self.message(for: error))
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
        guard canVerify else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await registerUseCase.verifyEmail(email: email, code: code)
            stopResendCountdown()
            go(to: .done)
        } catch {
            code = ""
            showError(Self.message(for: error))
        }
    }

    var canResend: Bool {
        resendSecondsLeft == 0 && !isLoading
    }

    var resendTitle: String {
        guard resendSecondsLeft > 0 else { return "Gửi lại mã" }
        return String(format: "Gửi lại sau %d:%02d", resendSecondsLeft / 60, resendSecondsLeft % 60)
    }

    func resendCode() async {
        guard canResend else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await registerUseCase.resendCode(email: email)
            code = ""
            startResendCountdown()
        } catch {
            showError(Self.message(for: error))
        }
    }

    func changeEmail() {
        stopResendCountdown()
        code = ""
        go(to: .info, back: true)
    }

    // MARK: - Điều hướng

    func goBack() {
        switch step {
        case .info: onCancel()
        case .password: go(to: .info, back: true)
        case .verify: changeEmail()
        case .done: break
        }
    }

    func cancel() {
        stopResendCountdown()
        onCancel()
    }

    func finish() {
        onFinished(normalizedEmail)
    }

    // MARK: - Private

    private func showError(_ message: String, title: String = RegisterViewModel.defaultErrorTitle) {
        errorTitle = title
        errorMessage = message
    }

    private func go(to newStep: Step, back: Bool = false) {
        isNavigatingBack = back
        step = newStep
    }

    private func startResendCountdown() {
        countdownTask?.cancel()
        resendSecondsLeft = Self.resendCooldown
        let sleep = sleep
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await sleep(.seconds(1)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.resendSecondsLeft = max(0, self.resendSecondsLeft - 1)
                if self.resendSecondsLeft == 0 { return }
            }
        }
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
