import Alamofire
import Foundation

protocol APIClient {
    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
}

final class AlamofireAPIClient: APIClient {
    private let baseURL: URL
    private let session: Session
    private let decoder: JSONDecoder

    /// - Parameter tokenRefresher: lấy lười (lazy) để tránh vòng phụ thuộc
    ///   APIClient → TokenRefresher → AuthRepository → APIClient khi khởi tạo DI.
    init(baseURL: URL, tokenStore: TokenStore, tokenRefresher: @escaping () -> TokenRefresher? = { nil }) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 30
        self.session = Session(
            configuration: configuration,
            interceptor: AuthInterceptor(tokenStore: tokenStore, tokenRefresher: tokenRefresher),
            eventMonitors: Self.eventMonitors
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

        let requestModifier: Session.RequestModifier? = endpoint.timeout.map { timeout in
            { $0.timeoutInterval = timeout }
        }

        let request: DataRequest
        if let files = endpoint.files {
            let fields = endpoint.formFields ?? [:]
            // UploadRequest là lớp con của DataRequest nên phần xử lý phản hồi bên dưới dùng chung,
            // kể cả gắn token và tự refresh khi 401.
            request = session.upload(
                multipartFormData: { form in
                    for (key, value) in fields {
                        form.append(Data(value.utf8), withName: key)
                    }
                    for file in files {
                        form.append(file.data, withName: file.fieldName, fileName: file.fileName, mimeType: file.mimeType)
                    }
                },
                to: url,
                method: endpoint.method,
                headers: headers,
                requestModifier: requestModifier
            )
        } else if let body = endpoint.body {
            request = session.request(
                url,
                method: endpoint.method,
                parameters: AnyEncodable(body),
                encoder: JSONParameterEncoder(encoder: Self.encoder),
                headers: headers,
                requestModifier: requestModifier
            )
        } else {
            request = session.request(
                url,
                method: endpoint.method,
                parameters: endpoint.queryItems,
                encoder: URLEncodedFormParameterEncoder.default,
                headers: headers,
                requestModifier: requestModifier
            )
        }

        let response = await request
            .validate(statusCode: 200..<300)
            .serializingData()
            .response

        // Đọc metadata trước để giữ thông báo lỗi, kể cả khi HTTP validation thất bại.
        let metadata = response.data.flatMap {
            try? decoder.decode(APIResponseMeta.self, from: $0)
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
           let empty = Self.defaultValue(of: T.self) {
            return empty
        }
        guard let body = response.data else { throw NetworkError.decoding }
        do {
            let envelope = try decoder.decode(APIResponse<T>.self, from: body)
            if let data = envelope.data { return data }
            if let empty = Self.defaultValue(of: T.self) { return empty }
            throw NetworkError.decoding
        } catch let error as NetworkError {
            throw error
        } catch {
            #if DEBUG
            print("❌ Decode \(T.self) thất bại tại \(url.absoluteString): \(error)")
            #endif
            throw NetworkError.decoding
        }
    }

    private static func defaultValue<T>(of type: T.Type) -> T? {
        (type as? DefaultDecodable.Type)?.init() as? T
    }

    private static var eventMonitors: [EventMonitor] {
        #if DEBUG
        return [NetworkLogger()]
        #else
        return []
        #endif
    }

    /// Backend nhận JSON camelCase (vd. `refreshToken`), nên giữ nguyên tên thuộc tính.
    private static let encoder = JSONEncoder()
}
