import Alamofire
import Foundation

/// Tự gắn Bearer token vào mọi request cần xác thực.
final class AuthInterceptor: RequestInterceptor, @unchecked Sendable {
    static let skipAuthHeader = "X-Skip-Auth"

    private let tokenStore: TokenStore

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
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

    private static func redactPassword(_ json: String) -> String {
        json.replacingOccurrences(
            of: #""password"\s*:\s*"[^"]*""#,
            with: #""password":"***""#,
            options: .regularExpression
        )
    }
}
