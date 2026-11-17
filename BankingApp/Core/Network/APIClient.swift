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

        let response = await request
            .validate(statusCode: 200..<300)
            .serializingData()
            .response

        // Đọc metadata trước để giữ thông báo lỗi, kể cả khi HTTP validation thất bại.
        let metadata = response.data.flatMap {
            try? decoder.decode(APIResponse<EmptyResponseDTO>.self, from: $0)
        }
        if let metadata,
           response.error == nil || response.response != nil {
            let status = response.response?.statusCode ?? metadata.httpStatus
            if !(200..<300).contains(status) || metadata.code != 0
                || !(200..<300).contains(metadata.httpStatus) {
                throw NetworkError.api(
                    code: metadata.code,
                    httpStatus: (200..<300).contains(status) ? metadata.httpStatus : status,
                    message: metadata.message,
                    traceId: metadata.traceId
                )
            }
        }
        if let error = response.error {
            throw NetworkError(error)
        }

        // HTTP 204/205 có thể không có body.
        if response.data?.isEmpty != false,
           let empty = EmptyResponseDTO() as? T {
            return empty
        }
        guard let body = response.data else { throw NetworkError.decoding }
        do {
            let envelope = try decoder.decode(APIResponse<T>.self, from: body)
            if let data = envelope.data { return data }
            if let empty = EmptyResponseDTO() as? T { return empty }
            throw NetworkError.decoding
        } catch {
            throw NetworkError.decoding
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}
