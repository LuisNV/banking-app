import XCTest
@testable import BankingApp

final class AppConfigTests: XCTestCase {
    private let info: [String: Any] = [
        "API_BASE_URL": "https://api-dev.example.com",
        "USE_MOCK_API": "NO",
    ]

    func test_readsValuesFromInfoPlist() {
        let config = AppConfig.load(info: info, environment: [:])
        XCTAssertEqual(config.baseURL.absoluteString, "https://api-dev.example.com")
        XCTAssertFalse(config.useMockAPI)
    }

    func test_schemeEnvironmentOverridesInfoPlist() {
        let config = AppConfig.load(
            info: info,
            environment: ["USE_MOCK_API": "YES", "API_BASE_URL": "http://localhost:8080"]
        )
        XCTAssertTrue(config.useMockAPI)
        XCTAssertEqual(config.baseURL.absoluteString, "http://localhost:8080")
    }

    func test_mockFlagAcceptsCommonTruthyValues() {
        for value in ["yes", "true", "1"] {
            XCTAssertTrue(AppConfig.load(info: info, environment: ["USE_MOCK_API": value]).useMockAPI, value)
        }
    }

    func test_missingMockFlagMeansRealAPI() {
        let config = AppConfig.load(info: ["API_BASE_URL": "https://api.example.com"], environment: [:])
        XCTAssertFalse(config.useMockAPI)
    }
}
