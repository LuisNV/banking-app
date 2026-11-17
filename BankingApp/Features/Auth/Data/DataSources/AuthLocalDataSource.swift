import Foundation

protocol AuthLocalDataSource {
    var refreshToken: String? { get }
    func saveTokens(accessToken: String, refreshToken: String) throws
    func clearTokens()

    var rememberedUsername: String? { get }
    func setRememberedUsername(_ username: String?)
}

final class AuthLocalDataSourceImpl: AuthLocalDataSource {
    private enum Key {
        static let rememberedUsername = "auth.remembered_username"
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
}
