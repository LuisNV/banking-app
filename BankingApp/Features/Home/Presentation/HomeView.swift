import PhotosUI
import SwiftUI

/// Màn hình sau đăng nhập (placeholder). Thay bằng dashboard thật.
struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var pickedPhoto: PhotosPickerItem?

    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        avatarPicker
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Xin chào,").foregroundStyle(AppColor.textSecondary)
                            Text(viewModel.user?.fullName ?? "Chào mừng bạn").font(.title2.bold())
                        }
                    }
                    .padding(.vertical, 8)
                }
                Section {
                    Button(role: .destructive) {
                        Task { await viewModel.logout() }
                    } label: {
                        Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(viewModel.isLoggingOut)
                }
            }
            .navigationTitle("Trang chủ")
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                Task { @MainActor in
                    defer { pickedPhoto = nil }
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        viewModel.errorMessage = ProfileError.invalidImage.errorDescription
                        return
                    }
                    await viewModel.uploadAvatar(from: data)
                }
            }
            .alert(
                "Không thể cập nhật ảnh",
                isPresented: $viewModel.isShowingError,
                presenting: viewModel.errorMessage
            ) { _ in
                Button("Đóng", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $pickedPhoto, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                avatarImage
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay {
                        if viewModel.isUploadingAvatar {
                            Circle().fill(.black.opacity(0.4))
                            ProgressView().tint(.white)
                        }
                    }

                Image(systemName: "camera.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Circle().fill(AppColor.brand))
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUploadingAvatar)
        .accessibilityLabel("Đổi ảnh đại diện")
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let data = viewModel.avatarImageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let url = viewModel.avatarURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                avatarPlaceholder
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(AppColor.textSecondary)
    }
}
