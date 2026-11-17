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

/// Log request/response trong môi trường dev.
final class NetworkLogger: EventMonitor, @unchecked Sendable {
    let queue = DispatchQueue(label: "network.logger")

    func requestDidFinish(_ request: Request) {
        #if DEBUG
        print("➡️ \(request.request?.httpMethod ?? "") \(request.request?.url?.absoluteString ?? "")")
        #endif
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        #if DEBUG
        print("⬅️ \(response.response?.statusCode ?? -1) \(request.request?.url?.absoluteString ?? "")")
        #endif
    }
}
