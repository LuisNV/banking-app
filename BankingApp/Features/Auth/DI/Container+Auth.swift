import Factory
import Foundation

extension Container {
    // MARK: Data
    var authRemoteDataSource: Factory<any AuthRemoteDataSource> {
        self { () -> any AuthRemoteDataSource in
            if self.appConfig().useMockAPI {
                return MockAuthRemoteDataSource()
            }
            return AuthRemoteDataSourceImpl(client: self.apiClient())
        }.singleton
    }

    var authLocalDataSource: Factory<any AuthLocalDataSource> {
        self {
            AuthLocalDataSourceImpl(tokenStore: self.tokenStore(), keyValueStore: self.keyValueStore())
        }.singleton
    }

    var authRepository: Factory<any AuthRepository> {
        self {
            AuthRepositoryImpl(remote: self.authRemoteDataSource(), local: self.authLocalDataSource())
        }.singleton
    }

    /// Dùng bởi `AuthInterceptor` để tự làm mới token khi API trả 401.
    var tokenRefresher: Factory<any TokenRefresher> {
        self {
            AuthTokenRefresher(repository: self.authRepository()) {
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
            }
        }.singleton
    }

    // MARK: Domain
    var loginUseCase: Factory<any LoginUseCaseProtocol> {
        self { LoginUseCase(repository: self.authRepository()) }
    }

    var biometricLoginUseCase: Factory<any BiometricLoginUseCaseProtocol> {
        self {
            BiometricLoginUseCase(repository: self.authRepository(), biometricService: self.biometricAuthService())
        }
    }

    var getLoginPreferencesUseCase: Factory<any GetLoginPreferencesUseCaseProtocol> {
        self {
            GetLoginPreferencesUseCase(repository: self.authRepository(), biometricService: self.biometricAuthService())
        }
    }

    var biometricLoginSettingUseCase: Factory<any BiometricLoginSettingUseCaseProtocol> {
        self {
            BiometricLoginSettingUseCase(repository: self.authRepository(), biometricService: self.biometricAuthService())
        }
    }

    var getStoredSessionUseCase: Factory<any GetStoredSessionUseCaseProtocol> {
        self { GetStoredSessionUseCase(repository: self.authRepository()) }
    }

    var logoutUseCase: Factory<any LogoutUseCaseProtocol> {
        self { LogoutUseCase(repository: self.authRepository()) }
    }
}
