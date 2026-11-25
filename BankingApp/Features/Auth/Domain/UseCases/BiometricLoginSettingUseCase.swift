import Foundation

/// Bật/tắt đăng nhập bằng sinh trắc học (màn Cá nhân).
protocol BiometricLoginSettingUseCaseProtocol {
    /// Loại sinh trắc học máy hỗ trợ; `.none` thì ẩn tuỳ chọn.
    var availableType: BiometricType { get }
    var isEnabled: Bool { get }
    /// Bật cần xác thực sinh trắc học trước; tắt thì không.
    /// - Returns: trạng thái sau khi đổi.
    func setEnabled(_ enabled: Bool) async -> Bool
}

struct BiometricLoginSettingUseCase: BiometricLoginSettingUseCaseProtocol {
    let repository: AuthRepository
    let biometricService: BiometricAuthService

    var availableType: BiometricType { biometricService.availableType }

    var isEnabled: Bool { repository.isBiometricLoginEnabled() }

    func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            let reason = "Xác thực để bật \(availableType.loginTitle.lowercased())"
            guard (try? await biometricService.authenticate(reason: reason)) == true else {
                return repository.isBiometricLoginEnabled()
            }
        }
        repository.setBiometricLoginEnabled(enabled)
        return enabled
    }
}
