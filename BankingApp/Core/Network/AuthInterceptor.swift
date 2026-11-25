import Alamofire
import Foundation

/// Làm mới cặp token bằng refresh token đã lưu (`POST v1/auth/refresh`).
/// Trả về `true` nếu đã có access token mới trong `TokenStore`.
protocol TokenRefresher: AnyObject {
    func refreshTokens() async -> Bool
}

/// - `adapt`: tự gắn Bearer token vào mọi request cần xác thực.
/// - `retry`: request bị 401 → làm mới token một lần rồi gửi lại.
final class AuthInterceptor: RequestInterceptor, @unchecked Sendable {
    static let skipAuthHeader = "X-Skip-Auth"

    private let tokenStore: TokenStore
    private let tokenRefresher: () -> TokenRefresher?

    init(tokenStore: TokenStore, tokenRefresher: @escaping () -> TokenRefresher? = { nil }) {
        self.tokenStore = tokenStore
        self.tokenRefresher = tokenRefresher
    }

    func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var request = urlRequest
        if request.value(forHTTPHeaderField: Self.skipAuthHeader) != nil {
            request.setValue(nil, forHTTPHeaderField: Self.skipAuthHeader)
        } else if let token = tokenStore.accessToken {
            request.headers.add(.authorization(bearerToken: token))
        }
        completion(.success(request))
    }

    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        // Chỉ xử lý request đã gắn token (không phải login/refresh/logout) bị 401, và chỉ thử lại 1 lần.
        guard request.response?.statusCode == 401,
              request.retryCount == 0,
              let usedHeader = request.request?.value(forHTTPHeaderField: "Authorization"),
              let refresher = tokenRefresher()
        else {
            completion(.doNotRetry)
            return
        }

        // Một request khác đã làm mới token trong lúc request này đang chạy: chỉ cần gửi lại.
        if let current = tokenStore.accessToken, usedHeader != "Bearer \(current)" {
            completion(.retry)
            return
        }

        Task {
            let refreshed = await refresher.refreshTokens()
            completion(refreshed ? .retry : .doNotRetry)
        }
    }
}

/// Log request/response trong bản Debug (xem ở console của Xcode).
final class NetworkLogger: EventMonitor, @unchecked Sendable {
    let queue = DispatchQueue(label: "network.logger")

    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        #if DEBUG
        var line = "➡️ \(urlRequest.httpMethod ?? "") \(urlRequest.url?.absoluteString ?? "")"
        if let body = urlRequest.httpBody, let text = String(data: body, encoding: .utf8) {
            line += "\n   body: \(Self.redactPassword(text))"
        }
        print(line)
        #endif
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        #if DEBUG
        let status = response.response?.statusCode.description ?? "—"
        var line = "⬅️ \(status) \(request.request?.url?.absoluteString ?? "")"
        if let data = response.data, let text = String(data: data, encoding: .utf8), !text.isEmpty {
            line += "\n   body: \(text.prefix(2000))"
        }
        if let error = response.error {
            line += "\n   ❌ \(error.underlyingError ?? error)"
        }
        print(line)
        #endif
    }

    /// Che mọi trường mật khẩu: `password`, `confirmPassword`, `currentPassword`, `newPassword`...
    static func redactPassword(_ json: String) -> String {
        json.replacingOccurrences(
            of: #""(\w*[Pp]assword)"\s*:\s*"[^"]*""#,
            with: #""$1":"***""#,
            options: .regularExpression
        )
    }
}
