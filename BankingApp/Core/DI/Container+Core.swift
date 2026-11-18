import Factory
import Foundation

/// Đăng ký các dependency dùng chung toàn app.
/// Mỗi feature có file `Container+<Feature>.swift` riêng.
extension Container {
    var appConfig: Factory<AppConfig> {
        self { AppConfig.current }.singleton
    }

    var tokenStore: Factory<any TokenStore> {
        self { KeychainTokenStore() }.singleton
    }

    var keyValueStore: Factory<any KeyValueStore> {
        self { UserDefaults.standard }.singleton
    }

    var apiClient: Factory<any APIClient> {
        self {
            AlamofireAPIClient(
                baseURL: self.appConfig().baseURL,
                tokenStore: self.tokenStore(),
                tokenRefresher: { self.tokenRefresher() }
            )
        }.singleton
    }

    var biometricAuthService: Factory<any BiometricAuthService> {
        self { LocalBiometricAuthService() }
    }
}
