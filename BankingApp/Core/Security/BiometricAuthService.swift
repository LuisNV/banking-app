import Foundation
import LocalAuthentication

enum BiometricType: Equatable {
    case none
    case faceID
    case touchID
    case opticID

    var displayName: String {
        switch self {
        case .none: return ""
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "lock"
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        }
    }
}

protocol BiometricAuthService {
    var availableType: BiometricType { get }
    func authenticate(reason: String) async throws -> Bool
}

final class LocalBiometricAuthService: BiometricAuthService {
    var availableType: BiometricType {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Huỷ"
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }
}
