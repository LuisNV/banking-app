import Factory
import Foundation
import Observation

/// Tuỳ chọn tài khoản ở màn Cá nhân: đăng nhập sinh trắc học, hỗ trợ, phiên bản.
@MainActor
@Observable
final class ProfileSettingsViewModel {
    let biometricType: BiometricType
    private(set) var isBiometricLoginEnabled: Bool
    private(set) var isUpdatingBiometric = false
    let support: SupportContact
    let versionText: String

    private let biometricSetting: BiometricLoginSettingUseCaseProtocol

    init(
        biometricSetting: BiometricLoginSettingUseCaseProtocol = Container.shared.biometricLoginSettingUseCase(),
        supportEmail: String = Container.shared.appConfig().supportEmail,
        appVersion: String = Bundle.main.shortVersion
    ) {
        self.biometricSetting = biometricSetting
        self.biometricType = biometricSetting.availableType
        self.isBiometricLoginEnabled = biometricSetting.isEnabled
        self.support = SupportContact(title: "Góp ý & hỗ trợ", email: supportEmail)
        self.versionText = "TingTing phiên bản \(appVersion)"
    }

    var showsBiometricOption: Bool { biometricType != .none }

    /// Vd. "Đăng nhập bằng Face ID".
    var biometricTitle: String { "Đăng nhập bằng \(biometricType.displayName)" }

    func setBiometricLoginEnabled(_ enabled: Bool) async {
        guard !isUpdatingBiometric, enabled != isBiometricLoginEnabled else { return }
        isUpdatingBiometric = true
        defer { isUpdatingBiometric = false }
        isBiometricLoginEnabled = await biometricSetting.setEnabled(enabled)
    }
}
