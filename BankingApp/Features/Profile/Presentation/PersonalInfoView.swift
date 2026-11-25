import SwiftUI

/// Màn "Thông tin cá nhân": dữ liệu từ `GET v1/auth/me`. Bấm "Sửa" để mở `EditProfileView`.
struct PersonalInfoView: View {
    let viewModel: HomeViewModel
    @State private var isChangingAvatar = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Button {
                        isChangingAvatar = true
                    } label: {
                        HomeAvatar(viewModel: viewModel, size: 80)
                            .overlay {
                                if viewModel.isUploadingAvatar {
                                    Circle().fill(.black.opacity(0.4))
                                    ProgressView().tint(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isUploadingAvatar)
                    .accessibilityLabel("Đổi ảnh đại diện")
                    Text(viewModel.fullName ?? "—")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                    if let profile = viewModel.profile, isEmailUnverified(profile) {
                        UnverifiedEmailNotice()
                    }
                }
                .frame(maxWidth: .infinity)

                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Thông tin cá nhân")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.profile != nil {
                    NavigationLink("Sửa", value: ProfileTabView.Route.editProfile)
                        .fontWeight(.semibold)
                }
            }
        }
        .refreshable { await viewModel.loadProfile(force: true) }
        .avatarPicker(isPresented: $isChangingAvatar) { jpegData in
            Task { await viewModel.uploadAvatar(from: jpegData) }
        }
        .task { await viewModel.loadProfile(force: true) }
    }

    @ViewBuilder
    private var content: some View {
        if let profile = viewModel.profile {
            details(profile)
        } else if viewModel.isLoadingProfile {
            ProgressView().frame(maxWidth: .infinity, minHeight: 120)
        } else if let message = viewModel.profileErrorMessage {
            errorView(message)
        }
    }

    private func details(_ profile: UserProfile) -> some View {
        VStack(spacing: 8) {
            // Biểu tượng và màu giống màn Sửa thông tin.
            GroupedCard {
                InfoRow(title: "Họ và tên", systemImage: "person.fill", tint: Color(.systemBlue),
                        value: profile.fullName)
                GroupedDivider()
                InfoRow(title: "Số điện thoại", systemImage: "phone.fill", tint: Color(.systemGreen),
                        value: profile.phone)
                GroupedDivider()
                InfoRow(title: "Email", systemImage: "envelope.fill", tint: Color(.systemIndigo),
                        value: profile.email)
                if let username = profile.username, username != profile.email {
                    GroupedDivider()
                    InfoRow(title: "Tên đăng nhập", systemImage: "at", tint: Color(.systemTeal),
                            value: username)
                }
            }

            GroupedCard {
                InfoRow(title: "Địa chỉ", systemImage: "house.fill", tint: Color(.systemOrange),
                        value: profile.address)
            }
            .padding(.top, 12)

            GroupedCard {
                InfoRow(title: "Giới tính", systemImage: "person.2.fill", tint: Color(.systemPurple),
                        value: profile.gender?.title)
                GroupedDivider()
                InfoRow(title: "Ngày sinh", systemImage: "calendar", tint: Color(.systemRed),
                        value: profile.birthDate.map(Self.formatBirthDate))
            }
            .padding(.top, 12)

            if let message = viewModel.profileErrorMessage {
                // Tải lại thất bại: vẫn giữ dữ liệu cũ, chỉ báo nhẹ.
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }
        }
    }

    /// Chỉ báo khi server nói rõ `emailVerified = false`.
    private func isEmailUnverified(_ profile: UserProfile) -> Bool {
        profile.email != nil && profile.isEmailVerified == false
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(AppColor.textSecondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("Thử lại") {
                Task { await viewModel.loadProfile(force: true) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    static func formatBirthDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

/// Một dòng thông tin: ô biểu tượng + nhãn + giá trị.
private struct InfoRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let value: String?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemImage: systemImage, tint: tint)
            Text(title)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize()
            Spacer(minLength: 8)
            Text(value ?? "Chưa cập nhật")
                .foregroundStyle(value == nil ? AppColor.textTertiary : AppColor.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

/// Thông báo email chưa xác minh, hiện dưới tên người dùng.
private struct UnverifiedEmailNotice: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color(.systemOrange))
                .accessibilityHidden(true)
            Text("Email chưa xác minh")
                .foregroundStyle(AppColor.textPrimary)
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Capsule().fill(Color(.systemOrange).opacity(0.15)))
        .accessibilityElement(children: .combine)
    }
}
