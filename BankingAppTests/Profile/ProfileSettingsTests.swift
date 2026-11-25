import XCTest
@testable import BankingApp

final class BiometricLoginSettingUseCaseTests: XCTestCase {
    private var repository: MockAuthRepository!
    private var biometric: MockBiometricAuthService!

    override func setUp() {
        super.setUp()
        repository = MockAuthRepository()
        biometric = MockBiometricAuthService()
    }

    private func makeSUT() -> BiometricLoginSettingUseCase {
        BiometricLoginSettingUseCase(repository: repository, biometricService: biometric)
    }

    func test_disable_savesWithoutAuthenticating() async {
        biometric.authenticateResult = .failure(AuthError.biometricFailed)

        let result = await makeSUT().setEnabled(false)

        XCTAssertFalse(result)
        XCTAssertFalse(repository.biometricLoginEnabled)
    }

    func test_enable_requiresSuccessfulAuthentication() async {
        repository.biometricLoginEnabled = false

        let result = await makeSUT().setEnabled(true)

        XCTAssertTrue(result)
        XCTAssertTrue(repository.biometricLoginEnabled)
    }

    func test_enable_authenticationFails_staysDisabled() async {
        repository.biometricLoginEnabled = false
        biometric.authenticateResult = .success(false)

        let result = await makeSUT().setEnabled(true)

        XCTAssertFalse(result)
        XCTAssertFalse(repository.biometricLoginEnabled)
    }

    func test_loginPreferences_hideBiometricLoginWhenDisabled() {
        repository.biometricLoginEnabled = false
        let preferences = GetLoginPreferencesUseCase(repository: repository, biometricService: biometric).execute()
        XCTAssertFalse(preferences.canUseBiometricLogin)

        repository.biometricLoginEnabled = true
        let enabled = GetLoginPreferencesUseCase(repository: repository, biometricService: biometric).execute()
        XCTAssertTrue(enabled.canUseBiometricLogin)
    }
}

private final class StubBiometricSetting: BiometricLoginSettingUseCaseProtocol {
    var availableType: BiometricType = .faceID
    var isEnabled = true
    var nextResult: Bool?
    private(set) var requests: [Bool] = []

    func setEnabled(_ enabled: Bool) async -> Bool {
        requests.append(enabled)
        isEnabled = nextResult ?? enabled
        return isEnabled
    }
}

@MainActor
final class ProfileSettingsViewModelTests: XCTestCase {
    func test_initialState() {
        let sut = ProfileSettingsViewModel(
            biometricSetting: StubBiometricSetting(), supportEmail: "help@tingting.vn", appVersion: "1.2.0"
        )

        XCTAssertTrue(sut.showsBiometricOption)
        XCTAssertEqual(sut.biometricTitle, "Đăng nhập bằng Face ID")
        XCTAssertTrue(sut.isBiometricLoginEnabled)
        XCTAssertEqual(sut.support.mailURL?.absoluteString, "mailto:help@tingting.vn")
        XCTAssertEqual(sut.versionText, "TingTing phiên bản 1.2.0")
    }

    func test_noBiometricHardware_hidesOption() {
        let setting = StubBiometricSetting()
        setting.availableType = .none
        let sut = ProfileSettingsViewModel(biometricSetting: setting, supportEmail: "a@b.c", appVersion: "1")
        XCTAssertFalse(sut.showsBiometricOption)
    }

    func test_toggle_reflectsUseCaseResult() async {
        let setting = StubBiometricSetting()
        let sut = ProfileSettingsViewModel(biometricSetting: setting, supportEmail: "a@b.c", appVersion: "1")

        await sut.setBiometricLoginEnabled(false)
        XCTAssertFalse(sut.isBiometricLoginEnabled)

        setting.nextResult = false // xác thực thất bại khi bật lại
        await sut.setBiometricLoginEnabled(true)
        XCTAssertFalse(sut.isBiometricLoginEnabled)
        XCTAssertEqual(setting.requests, [false, true])
        XCTAssertFalse(sut.isUpdatingBiometric)
    }

    func test_toggle_sameValue_doesNothing() async {
        let setting = StubBiometricSetting()
        let sut = ProfileSettingsViewModel(biometricSetting: setting, supportEmail: "a@b.c", appVersion: "1")

        await sut.setBiometricLoginEnabled(true)

        XCTAssertTrue(setting.requests.isEmpty)
    }
}
