import Foundation

/// Cấu hình môi trường, đọc từ Info.plist (giá trị đến từ build settings trong project.yml).
struct AppConfig {
    let baseURL: URL
    let useMockAPI: Bool
    /// TODO: thay bằng số tổng đài thật.
    let supportHotline: String

    static let current: AppConfig = {
        let info = Bundle.main.infoDictionary ?? [:]
        let urlString = info["API_BASE_URL"] as? String ?? "https://api.example.com"
        let useMock = (info["USE_MOCK_API"] as? String) == "YES"
        return AppConfig(
            baseURL: URL(string: urlString) ?? URL(string: "https://api.example.com")!,
            useMockAPI: useMock,
            supportHotline: "1900 0000"
        )
    }()
}
