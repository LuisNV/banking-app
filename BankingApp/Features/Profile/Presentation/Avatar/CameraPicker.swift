import AVFoundation
import SwiftUI
import UIKit

/// Màn chụp ảnh của hệ thống (UIImagePickerController). Mặc định dùng camera trước.
struct CameraPicker: UIViewControllerRepresentable {
    let onCaptured: (UIImage?) -> Void

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if UIImagePickerController.isCameraDeviceAvailable(.front) {
            picker.cameraDevice = .front
        }
        // Tự cắt bằng AvatarCropView nên tắt khung chỉnh của hệ thống.
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCaptured: onCaptured) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCaptured: (UIImage?) -> Void

        init(onCaptured: @escaping (UIImage?) -> Void) {
            self.onCaptured = onCaptured
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onCaptured(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCaptured(nil)
        }
    }
}

enum CameraPermission {
    enum Status { case allowed, denied }

    /// Hỏi quyền nếu chưa hỏi. `denied` khi người dùng đã từ chối hoặc bị giới hạn.
    static func request() async -> Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .allowed
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .allowed : .denied
        default:
            return .denied
        }
    }
}
