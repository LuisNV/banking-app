import Alamofire
import Foundation

enum NetworkError: Error, Equatable {
    case noConnection
    case timeout
    case unauthorized
    case server(statusCode: Int)
    case decoding
    case unknown

    init(_ error: AFError) {
        if let code = error.responseCode {
            self = code == 401 ? .unauthorized : .server(statusCode: code)
            return
        }
        if case .responseSerializationFailed = error {
            self = .decoding
            return
        }
        if let urlError = error.underlyingError as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost: self = .noConnection
            case .timedOut: self = .timeout
            default: self = .unknown
            }
            return
        }
        self = .unknown
    }
}
