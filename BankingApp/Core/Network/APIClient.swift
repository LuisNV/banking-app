import Alamofire
import Foundation

protocol APIClient {
    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
}

final class AlamofireAPIClient: APIClient {
    private let baseURL: URL
    private let session: Session
    private let decoder: JSONDecoder

    init(baseURL: URL, tokenStore: TokenStore) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 30
        self.session = Session(
            configuration: configuration,
            interceptor: AuthInterceptor(tokenStore: tokenStore),
            eventMonitors: AppConfig.current.useMockAPI ? [NetworkLogger()] : []
        )
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var headers: HTTPHeaders = [.accept("application/json")]
        if !endpoint.requiresAuth {
            headers.add(name: AuthInterceptor.skipAuthHeader, value: "1")
        }

        let request: DataRequest
        if let body = endpoint.body {
            request = session.request(
                url,
                method: endpoint.method,
                parameters: AnyEncodable(body),
                encoder: JSONParameterEncoder(encoder: Self.encoder),
                headers: headers
            )
        } else {
            request = session.request(
                url,
                method: endpoint.method,
                parameters: endpoint.queryItems,
                encoder: URLEncodedFormParameterEncoder.default,
                headers: headers
            )
        }

        do {
            return try await request
                .validate(statusCode: 200..<300)
                .serializingDecodable(T.self, decoder: decoder)
                .value
        } catch let error as AFError {
            throw NetworkError(error)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}
