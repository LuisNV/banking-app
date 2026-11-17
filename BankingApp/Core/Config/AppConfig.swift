import Foundation

/// Cấu hình môi trường.
///
/// Thứ tự ưu tiên khi đọc mỗi khoá:
/// 1. Biến môi trường của scheme (Xcode ▸ Edit Scheme ▸ Run ▸ Arguments ▸ Environment Variables)
/// 2. Info.plist (giá trị lấy từ build settings Debug/Release trong project.yml)
///
/// Bản Release luôn gọi API thật, kể cả khi cấu hình nhầm USE_MOCK_API.
struct AppConfig {
    let baseURL: URL
    let useMockAPI: Bool
    /// TODO: thay bằng email hỗ trợ thật.
    let supportEmail: String

    static let current = AppConfig.load()

    static func load(
        info: [String: Any] = Bundle.main.infoDictionary ?? [:],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppConfig {
        func value(_ key: String) -> String? {
            if let raw = environment[key]?.trimmingCharacters(in: .whitespaces), !raw.isEmpty {
                return raw
            }
            // "$(...)" nghĩa là build setting chưa được thay giá trị (thiếu trong project.yml).
            if let raw = (info[key] as? String)?.trimmingCharacters(in: .whitespaces),
               !raw.isEmpty, !raw.hasPrefix("$(") {
                return raw
            }
            return nil
        }

        let urlString = value("API_BASE_URL") ?? ""
        let baseURL: URL
        if let url = URL(string: urlString), url.scheme != nil, url.host != nil {
            baseURL = url
        } else {
            assertionFailure("API_BASE_URL không hợp lệ: '\(urlString)'. Sửa project.yml rồi chạy lại `xcodegen generate`.")
            baseURL = URL(string: "http://localhost:8081/api")!
        }

        #if DEBUG
        let useMock = ["YES", "TRUE", "1"].contains((value("USE_MOCK_API") ?? "NO").uppercased())
        #else
        let useMock = false
        #endif

        return AppConfig(baseURL: baseURL, useMockAPI: useMock, supportEmail: "support@example.com")
    }

    /// In ra console khi khởi động để biết app đang gọi API thật hay mock.
    func logSummary() {
        #if DEBUG
        print("⚙️ AppConfig — \(useMockAPI ? "MOCK API (không gọi mạng)" : "API thật: \(baseURL.absoluteString)")")
        #endif
    }
}
