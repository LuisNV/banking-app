import SwiftUI

/// Màn "Thông tin cá nhân": dữ liệu từ `GET v1/auth/me`. Bấm "Sửa" để mở `EditProfileView`.
struct PersonalInfoView: View {
    let viewModel: HomeViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    HomeAvatar(viewModel: viewModel, size: 80)
                    Text(viewModel.fullName ?? "—")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
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
            GroupedCard {
                InfoRow(title: "Họ và tên", value: profile.fullName)
                GroupedDivider(leadingInset: 16)
                InfoRow(title: "Email", value: profile.email, badge: emailBadge(profile))
                if let username = profile.username, username != profile.email {
                    GroupedDivider(leadingInset: 16)
                    InfoRow(title: "Tên đăng nhập", value: username)
                }
                GroupedDivider(leadingInset: 16)
                InfoRow(title: "Số điện thoại", value: profile.phone)
                GroupedDivider(leadingInset: 16)
                InfoRow(title: "Ngày sinh", value: profile.birthDate.map(Self.formatBirthDate))
                GroupedDivider(leadingInset: 16)
                InfoRow(title: "Giới tính", value: profile.gender?.title)
                GroupedDivider(leadingInset: 16)
                InfoRow(title: "Địa chỉ", value: profile.address)
            }

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

    private func emailBadge(_ profile: UserProfile) -> InfoRow.Badge? {
        guard profile.email != nil, let verified = profile.isEmailVerified else { return nil }
        return verified ? .verified : .unverified
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

private struct InfoRow: View {
    enum Badge {
        case verified, unverified
    }

    let title: String
    let value: String?
    var badge: Badge?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(AppColor.textSecondary)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value ?? "Chưa cập nhật")
                    .foregroundStyle(value == nil ? AppColor.textTertiary : AppColor.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
                badgeView
            }
        }
        .font(.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 50)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var badgeView: some View {
        switch badge {
        case .verified:
            Label("Đã xác minh", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.success)
        case .unverified:
            Label("Chưa xác minh", systemImage: "exclamationmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.systemOrange))
        case nil:
            EmptyView()
        }
    }
}
