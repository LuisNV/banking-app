import Factory
import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    // MARK: Input
    var username = ""
    var password = ""
    var isPasswordVisible = false
    var rememberMe = true
    var isDrawerOpen = false

    // MARK: Output
    private(set) var isLoading = false
    private(set) var biometricType: BiometricType = .faceID
    private(set) var canUseBiometricLogin = false
    var errorMessage: String?

    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
    }

    var showsBiometricButton: Bool { biometricType != .none }

    // MARK: Dependencies
    private let loginUseCase: LoginUseCaseProtocol
    private let biometricLoginUseCase: BiometricLoginUseCaseProtocol
    private let getPreferencesUseCase: GetLoginPreferencesUseCaseProtocol
    private let onAuthenticated: (AuthSession) -> Void

    init(
        loginUseCase: LoginUseCaseProtocol = Container.shared.loginUseCase(),
        biometricLoginUseCase: BiometricLoginUseCaseProtocol = Container.shared.biometricLoginUseCase(),
        getPreferencesUseCase: GetLoginPreferencesUseCaseProtocol = Container.shared.getLoginPreferencesUseCase(),
        onAuthenticated: @escaping (AuthSession) -> Void
    ) {
        self.loginUseCase = loginUseCase
        self.biometricLoginUseCase = biometricLoginUseCase
        self.getPreferencesUseCase = getPreferencesUseCase
        self.onAuthenticated = onAuthenticated
    }

    // MARK: Actions
    func onAppear() {
        let preferences = getPreferencesUseCase.execute()
        biometricType = preferences.biometricType
        canUseBiometricLogin = preferences.canUseBiometricLogin
        if let remembered = preferences.rememberedUsername, username.isEmpty {
            username = remembered
            rememberMe = true
        }
    }

    func login() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await loginUseCase.execute(
                username: username,
                password: password,
                rememberUsername: rememberMe
            )
            password = ""
            onAuthenticated(session)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func loginWithBiometrics() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await biometricLoginUseCase.execute()
            onAuthenticated(session)
        } catch AuthError.biometricFailed {
            // Người dùng huỷ hoặc quét không khớp: không cần báo lỗi.
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func toggleDrawer() {
        isDrawerOpen.toggle()
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? AuthError.unknown.errorDescription ?? ""
    }
}
