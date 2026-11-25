import XCTest
@testable import BankingApp

private final class InMemoryKeyValueStore: KeyValueStore {
    private var values: [String: Any] = [:]
    func string(forKey key: String) -> String? { values[key] as? String }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values[key] = nil }
}

private final class InMemoryTokenStore: TokenStore {
    var accessToken: String?
    var refreshToken: String?
    func save(accessToken: String, refreshToken: String) throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
    func clear() {
        accessToken = nil
        refreshToken = nil
    }
}

final class AuthStoredSessionTests: XCTestCase {
    func test_localDataSource_savedUser_roundTrip() {
        let sut = AuthLocalDataSourceImpl(tokenStore: InMemoryTokenStore(), keyValueStore: InMemoryKeyValueStore())
        let user = User(id: "u_001", fullName: "Nguyễn Minh Anh", username: "minhanh@email.com")

        sut.saveUser(user)
        XCTAssertEqual(sut.savedUser, user)

        sut.saveUser(nil)
        XCTAssertNil(sut.savedUser)
    }

    func test_getStoredSession_withRefreshToken_returnsSavedUser() {
        let repository = MockAuthRepository()
        repository.storedSession = true
        repository.savedUser = User(id: "1", fullName: "A", username: "a")

        let result = GetStoredSessionUseCase(repository: repository).execute()

        XCTAssertEqual(result, StoredSession(user: repository.savedUser))
    }

    func test_getStoredSession_withoutRefreshToken_returnsNil() {
        let repository = MockAuthRepository()
        repository.storedSession = false
        repository.savedUser = User(id: "1", fullName: "A", username: "a")

        XCTAssertNil(GetStoredSessionUseCase(repository: repository).execute())
    }
}
