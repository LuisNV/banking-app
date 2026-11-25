import PhotosUI
import SwiftUI

/// Tab "Cá nhân": ảnh đại diện + đăng xuất. TODO: làm theo thiết kế màn Cá nhân.
struct ProfileTabView: View {
    let viewModel: HomeViewModel
    @State private var pickedPhoto: PhotosPickerItem?

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
            .navigationTitle("Cá nhân")
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
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $pickedPhoto, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                HomeAvatar(viewModel: viewModel, size: 64)
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
}

/// Màn tạm cho các tab chưa làm.
struct ComingSoonTabView: View {
    let tab: HomeViewModel.Tab

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                tab.title,
                systemImage: tab.systemImage,
                description: Text("Tính năng đang được phát triển.")
            )
            .navigationTitle(tab.title)
        }
    }
}
