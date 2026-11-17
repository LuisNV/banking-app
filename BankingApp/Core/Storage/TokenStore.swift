import Foundation
import KeychainAccess

/// Lưu token trong Keychain. Không bao giờ lưu token ở UserDefaults.
protocol TokenStore: AnyObject {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    func save(accessToken: String, refreshToken: String) throws
    func clear()
}

final class KeychainTokenStore: TokenStore {
    private enum Key {
        static let accessToken = "auth.access_token"
        static let refreshToken = "auth.refresh_token"
    }

    private let keychain: Keychain

    init(service: String = Bundle.main.bundleIdentifier ?? "com.example.banking") {
        keychain = Keychain(service: service)
            .accessibility(.whenUnlockedThisDeviceOnly)
    }

    var accessToken: String? { try? keychain.get(Key.accessToken) }
    var refreshToken: String? { try? keychain.get(Key.refreshToken) }

    func save(accessToken: String, refreshToken: String) throws {
        try keychain.set(accessToken, key: Key.accessToken)
        try keychain.set(refreshToken, key: Key.refreshToken)
    }

    func clear() {
        try? keychain.remove(Key.accessToken)
        try? keychain.remove(Key.refreshToken)
    }
}
