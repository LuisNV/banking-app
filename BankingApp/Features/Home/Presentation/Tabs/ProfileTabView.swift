import PhotosUI
import SwiftUI

/// Tab "Cá nhân": ảnh đại diện, thống kê học, cài đặt tài khoản/học tập, hỗ trợ, đăng xuất.
struct ProfileTabView: View {
    enum Route: Hashable {
        case personalInfo
        case changePassword
        case dailyGoal
        case reminder
        case script

        var title: String {
            switch self {
            case .personalInfo: return "Thông tin cá nhân"
            case .changePassword: return "Đổi mật khẩu"
            case .dailyGoal: return "Mục tiêu mỗi ngày"
            case .reminder: return "Nhắc học"
            case .script: return "Chữ Hán"
            }
        }
    }

    let viewModel: HomeViewModel
    @State private var settings = ProfileSettingsViewModel()
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isConfirmingLogout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    statsCard.padding(.top, 20)
                    accountSection.padding(.top, 22)
                    learningSection.padding(.top, 22)
                    supportAndLogout.padding(.top, 22)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("Cá nhân")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Sửa", value: Route.personalInfo)
                        .fontWeight(.semibold)
                }
            }
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
            .task { await viewModel.loadDashboard() }
            .refreshable { await viewModel.loadProfile(force: true) }
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
            // Dùng alert (không dùng confirmationDialog): từ iOS 26 confirmationDialog hiện dạng
            // bong bóng và ẩn nút Huỷ, còn alert luôn là hộp thoại giữa màn hình có đủ hai nút.
            .alert("Đăng xuất", isPresented: $isConfirmingLogout) {
                Button("Huỷ", role: .cancel) {}
                Button("Đăng xuất", role: .destructive) {
                    Task { await viewModel.logout() }
                }
            } message: {
                Text("Bạn có chắc muốn đăng xuất khỏi TingTing?")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 0) {
            avatarPicker
            Text(viewModel.fullName ?? "Chào mừng bạn")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 14)
            if let subtitle = viewModel.accountSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.top, 2)
            }
            if let level = viewModel.dashboard?.learner.levelTitle {
                Text(level)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.brandDark)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(AppColor.brand.opacity(0.12)))
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $pickedPhoto, matching: .images) {
            HomeAvatar(viewModel: viewModel, size: 96)
                .overlay {
                    if viewModel.isUploadingAvatar {
                        Circle().fill(.black.opacity(0.4))
                        ProgressView().tint(.white)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppColor.brand))
                        .overlay(Circle().strokeBorder(AppColor.background, lineWidth: 3))
                        .offset(x: 2, y: 2)
                }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUploadingAvatar)
        .accessibilityLabel("Đổi ảnh đại diện")
    }

    // MARK: Stats

    @ViewBuilder
    private var statsCard: some View {
        if let dashboard = viewModel.dashboard {
            HStack(spacing: 0) {
                ProfileStat(value: "\(dashboard.streakDays)", label: "Ngày liên tiếp")
                Rectangle().fill(AppColor.separator).frame(width: 0.5)
                ProfileStat(value: "\(dashboard.learner.wordsLearned)", label: "Từ đã học")
                Rectangle().fill(AppColor.separator).frame(width: 0.5)
                ProfileStat(value: "\(dashboard.learner.lessonsCompleted)", label: "Bài hoàn thành")
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 14)
            .background(
                AppColor.field,
                in: RoundedRectangle(cornerRadius: AppMetrics.groupedCardRadius, style: .continuous)
            )
        }
    }

    // MARK: Sections

    private var accountSection: some View {
        VStack(spacing: 8) {
            ProfileSectionHeader(title: "Tài khoản")
            GroupedCard {
                NavigationLink(value: Route.personalInfo) {
                    ProfileRowLabel(title: "Thông tin cá nhân", systemImage: "person.fill", tint: Color(.systemBlue))
                }
                GroupedDivider()
                NavigationLink(value: Route.changePassword) {
                    ProfileRowLabel(title: "Đổi mật khẩu", systemImage: "lock.fill", tint: Color(.systemGray))
                }
                if settings.showsBiometricOption {
                    GroupedDivider()
                    ProfileToggleRow(
                        title: settings.biometricTitle,
                        systemImage: settings.biometricType.systemImage,
                        tint: Color(.systemGreen),
                        isOn: Binding(
                            get: { settings.isBiometricLoginEnabled },
                            set: { newValue in
                                Task { await settings.setBiometricLoginEnabled(newValue) }
                            }
                        ),
                        isDisabled: settings.isUpdatingBiometric
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var learningSection: some View {
        let dashboard = viewModel.dashboard
        return VStack(spacing: 8) {
            ProfileSectionHeader(title: "Học tập")
            GroupedCard {
                NavigationLink(value: Route.dailyGoal) {
                    ProfileRowLabel(
                        title: "Mục tiêu mỗi ngày",
                        systemImage: "target",
                        tint: Color(.systemOrange),
                        value: dashboard.map { "\($0.dailyGoal.targetMinutes) phút" }
                    )
                }
                GroupedDivider()
                NavigationLink(value: Route.reminder) {
                    ProfileRowLabel(
                        title: "Nhắc học",
                        systemImage: "bell.fill",
                        tint: Color(.systemRed),
                        value: dashboard.map { $0.learner.reminderTime ?? "Tắt" }
                    )
                }
                GroupedDivider()
                NavigationLink(value: Route.script) {
                    ProfileRowLabel(
                        title: "Chữ Hán",
                        systemImage: "globe",
                        tint: Color(.systemIndigo),
                        value: dashboard?.learner.scriptName
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var supportAndLogout: some View {
        VStack(spacing: 8) {
            GroupedCard {
                if let url = settings.support.mailURL {
                    Link(destination: url) {
                        ProfileRowLabel(
                            title: settings.support.title,
                            systemImage: "bubble.left.fill",
                            tint: Color(.systemTeal)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Gửi email tới \(settings.support.email)")
                }
            }

            GroupedCard {
                Button {
                    isConfirmingLogout = true
                } label: {
                    Text("Đăng xuất")
                        .font(.body)
                        .foregroundStyle(AppColor.danger)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoggingOut)
            }
            .padding(.top, 12)

            Text(settings.versionText)
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                .padding(.top, 4)
        }
    }

    // MARK: Destinations

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .personalInfo:
            PersonalInfoView(viewModel: viewModel)
        case .changePassword, .dailyGoal, .reminder, .script:
            ContentUnavailableView(
                route.title,
                systemImage: "hammer",
                description: Text("Tính năng đang được phát triển.")
            )
            .navigationTitle(route.title)
            .navigationBarTitleDisplayMode(.inline)
        }
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
