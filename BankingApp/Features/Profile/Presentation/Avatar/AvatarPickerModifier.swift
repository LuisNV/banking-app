import PhotosUI
import SwiftUI
import UIKit

/// Luồng đổi ảnh đại diện: bottom sheet chọn nguồn → chụp ảnh / thư viện → chỉnh cho vừa khung tròn.
/// Dùng: `.avatarPicker(isPresented: $isChangingAvatar) { jpegData in ... }`.
private struct AvatarPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onPicked: (Data) -> Void

    @State private var pendingSource: AvatarSourceSheet.Source?
    @State private var isShowingCamera = false
    @State private var isShowingLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var imageToCrop: CroppableImage?
    @State private var isShowingCameraDenied = false
    @State private var isShowingLoadError = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: openPendingSource) {
                AvatarSourceSheet(
                    isCameraAvailable: CameraPicker.isAvailable,
                    onSelect: { source in
                        pendingSource = source
                        isPresented = false
                    },
                    onCancel: { isPresented = false }
                )
            }
            .fullScreenCover(isPresented: $isShowingCamera, onDismiss: cropCapturedImage) {
                CameraPicker { image in
                    capturedImage = image
                    isShowingCamera = false
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $isShowingLibrary, selection: $libraryItem, matching: .images)
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                Task { @MainActor in
                    defer { libraryItem = nil }
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data)
                    else {
                        isShowingLoadError = true
                        return
                    }
                    imageToCrop = CroppableImage(image: image)
                }
            }
            .fullScreenCover(item: $imageToCrop) { item in
                AvatarCropView(
                    image: item.image,
                    onCancel: { imageToCrop = nil },
                    onCropped: { cropped in
                        imageToCrop = nil
                        if let data = cropped.jpegData(compressionQuality: 0.9) {
                            onPicked(data)
                        } else {
                            isShowingLoadError = true
                        }
                    }
                )
            }
            .alert("Chưa có quyền dùng camera", isPresented: $isShowingCameraDenied) {
                Button("Để sau", role: .cancel) {}
                Button("Mở Cài đặt") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Vào Cài đặt › TingTing và bật Camera để chụp ảnh đại diện.")
            }
            .alert("Không đọc được ảnh", isPresented: $isShowingLoadError) {
                Button("Đóng", role: .cancel) {}
            } message: {
                Text(ProfileError.invalidImage.errorDescription ?? "")
            }
    }

    /// Chạy sau khi bottom sheet đóng hẳn, để không mở hai màn chồng lúc đang chuyển cảnh.
    private func openPendingSource() {
        guard let source = pendingSource else { return }
        pendingSource = nil
        switch source {
        case .library:
            isShowingLibrary = true
        case .camera:
            Task { @MainActor in
                switch await CameraPermission.request() {
                case .allowed: isShowingCamera = true
                case .denied: isShowingCameraDenied = true
                }
            }
        }
    }

    private func cropCapturedImage() {
        guard let image = capturedImage else { return }
        capturedImage = nil
        imageToCrop = CroppableImage(image: image)
    }
}

private struct CroppableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

extension View {
    /// Gắn luồng đổi ảnh đại diện. `onPicked` nhận ảnh JPEG vuông đã chỉnh.
    func avatarPicker(isPresented: Binding<Bool>, onPicked: @escaping (Data) -> Void) -> some View {
        modifier(AvatarPickerModifier(isPresented: isPresented, onPicked: onPicked))
    }
}
