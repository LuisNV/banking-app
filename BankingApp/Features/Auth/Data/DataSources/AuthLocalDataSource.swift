import Foundation

protocol AuthLocalDataSource {
    var refreshToken: String? { get }
    func saveTokens(accessToken: String, refreshToken: String) throws
    func clearTokens()

    var rememberedUsername: String? { get }
    func setRememberedUsername(_ username: String?)

    /// Thông tin người dùng của phiên đang lưu (để mở app là hiện đúng tên, kể cả khi offline).
    var savedUser: User? { get }
    func saveUser(_ user: User?)

    /// Người dùng có cho phép đăng nhập bằng sinh trắc học không (mặc định: có).
    var isBiometricLoginEnabled: Bool { get }
    func setBiometricLoginEnabled(_ enabled: Bool)
}

final class AuthLocalDataSourceImpl: AuthLocalDataSource {
    private enum Key {
        static let rememberedUsername = "auth.remembered_username"
        /// Lưu cờ "đã tắt" để mặc định (chưa lưu gì) là bật.
        static let biometricLoginDisabled = "auth.biometric_login_disabled"
        static let savedUser = "auth.saved_user"
    }

    private let tokenStore: TokenStore
    private let keyValueStore: KeyValueStore

    init(tokenStore: TokenStore, keyValueStore: KeyValueStore) {
        self.tokenStore = tokenStore
        self.keyValueStore = keyValueStore
    }

    var refreshToken: String? { tokenStore.refreshToken }

    func saveTokens(accessToken: String, refreshToken: String) throws {
        try tokenStore.save(accessToken: accessToken, refreshToken: refreshToken)
    }

    func clearTokens() {
        tokenStore.clear()
    }

    var rememberedUsername: String? {
        keyValueStore.string(forKey: Key.rememberedUsername)
    }

    func setRememberedUsername(_ username: String?) {
        if let username {
            keyValueStore.set(username, forKey: Key.rememberedUsername)
        } else {
            keyValueStore.removeObject(forKey: Key.rememberedUsername)
        }
    }

    var savedUser: User? {
        guard let json = keyValueStore.string(forKey: Key.savedUser),
              let data = json.data(using: .utf8),
              let stored = try? JSONDecoder().decode(StoredUser.self, from: data)
        else { return nil }
        return User(id: stored.id, fullName: stored.fullName, username: stored.username)
    }

    func saveUser(_ user: User?) {
        guard let user,
              let data = try? JSONEncoder().encode(
                StoredUser(id: user.id, fullName: user.fullName, username: user.username)
              ),
              let json = String(data: data, encoding: .utf8)
        else {
            keyValueStore.removeObject(forKey: Key.savedUser)
            return
        }
        keyValueStore.set(json, forKey: Key.savedUser)
    }

    var isBiometricLoginEnabled: Bool {
        !keyValueStore.bool(forKey: Key.biometricLoginDisabled)
    }

    func setBiometricLoginEnabled(_ enabled: Bool) {
        keyValueStore.set(!enabled, forKey: Key.biometricLoginDisabled)
    }
}

/// Dạng lưu của `User` (Domain không phụ thuộc Codable).
private struct StoredUser: Codable {
    let id: String
    let fullName: String
    let username: String
}
