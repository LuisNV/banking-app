import SwiftUI

/// Đổi mật khẩu: mở toàn màn hình từ tab Cá nhân (che thanh tab), có NavigationStack riêng.
struct ChangePasswordView: View {
    @State private var viewModel: ChangePasswordViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ChangePasswordViewModel = ChangePasswordViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .form:
                    ChangePasswordFormStep(viewModel: viewModel)
                        .transition(.push(from: .leading))
                case .verify:
                    ChangePasswordVerifyStep(viewModel: viewModel)
                        .transition(.push(from: .trailing))
                case .done:
                    ChangePasswordDoneStep(viewModel: viewModel, onClose: { dismiss() })
                        .transition(.opacity)
                }
            }
            .animation(.snappy(duration: 0.35), value: viewModel.step)
            .background(AppColor.background)
            .navigationTitle("Đổi mật khẩu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .alert(
                "Không thể đổi mật khẩu",
                isPresented: $viewModel.isShowingAlert,
                presenting: viewModel.alertMessage
            ) { _ in
                Button("Đóng", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
        .interactiveDismissDisabled(viewModel.isLoading)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            switch viewModel.step {
            case .form:
                Button("Huỷ") { dismiss() }
                    .disabled(viewModel.isLoading)
            case .verify:
                Button {
                    viewModel.backToForm()
                } label: {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                }
                .accessibilityLabel("Quay lại")
                .disabled(viewModel.isLoading)
            case .done:
                EmptyView()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.step != .done {
                Text(viewModel.step == .form ? "1 / 2" : "2 / 2")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityLabel(viewModel.step == .form ? "Bước 1 trên 2" : "Bước 2 trên 2")
            }
        }
    }
}

// MARK: - Bước 1

private struct ChangePasswordFormStep: View {
    @Bindable var viewModel: ChangePasswordViewModel
    @FocusState private var focused: PasswordChangeField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Mật khẩu hiện tại")
                GroupedCard {
                    FormFieldRow(
                        "Mật khẩu hiện tại",
                        systemImage: "lock.fill",
                        tint: Color(.systemGray),
                        text: $viewModel.currentPassword,
                        status: viewModel.status(for: .current),
                        isSecure: true,
                        isRevealed: $viewModel.isCurrentRevealed,
                        textContentType: .password,
                        onSubmit: { focused = .new }
                    )
                    .focused($focused, equals: .current)
                    .disabled(viewModel.isLocked)
                }
                ErrorText(viewModel.error(for: .current))

                SectionTitle("Mật khẩu mới").padding(.top, 14)
                GroupedCard {
                    FormFieldRow(
                        "Mật khẩu mới",
                        systemImage: "key.fill",
                        tint: AppColor.brand,
                        text: $viewModel.newPassword,
                        status: viewModel.status(for: .new),
                        isSecure: true,
                        isRevealed: $viewModel.isNewRevealed,
                        textContentType: .newPassword,
                        onSubmit: { focused = .confirm }
                    )
                    .focused($focused, equals: .new)

                    GroupedDivider()

                    FormFieldRow(
                        "Nhập lại mật khẩu mới",
                        systemImage: "key.fill",
                        tint: AppColor.brand,
                        text: $viewModel.confirmPassword,
                        status: viewModel.status(for: .confirm),
                        isSecure: true,
                        isRevealed: $viewModel.isNewRevealed,
                        textContentType: .newPassword,
                        submitLabel: .go,
                        onSubmit: submit
                    )
                    .focused($focused, equals: .confirm)

                    GroupedDivider(leadingInset: 16)
                    StrengthRow(strength: viewModel.passwordEvaluation.strength)
                }
                ErrorText(viewModel.error(for: .new))
                ErrorText(viewModel.error(for: .confirm))

                SectionTitle("Yêu cầu", uppercase: false).padding(.top, 14)
                GroupedCard {
                    let evaluation = viewModel.passwordEvaluation
                    RequirementRow(text: "Ít nhất \(PasswordEvaluation.minimumLength) ký tự", isMet: evaluation.hasMinimumLength)
                    RequirementRow(text: "Chữ hoa và chữ thường", isMet: evaluation.hasUpperAndLowercase)
                    RequirementRow(text: "Ít nhất 1 chữ số", isMet: evaluation.hasDigit)
                    RequirementRow(text: "Khác mật khẩu hiện tại", isMet: viewModel.isDifferentFromCurrent)
                }

                GroupedCard {
                    HStack(spacing: 14) {
                        IconTile(systemImage: "laptopcomputer.and.iphone", tint: Color(.systemOrange))
                        Toggle("Đăng xuất khỏi thiết bị khác", isOn: $viewModel.logoutOtherDevices)
                            .tint(AppColor.success)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                }
                .padding(.top, 14)
                Text("Máy này vẫn giữ đăng nhập. Các máy khác phải đăng nhập lại bằng mật khẩu mới.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .onChange(of: viewModel.currentPassword) { _, _ in viewModel.didEdit(.current) }
        .onChange(of: viewModel.newPassword) { _, _ in viewModel.didEdit(.new) }
        .onChange(of: viewModel.confirmPassword) { _, _ in viewModel.didEdit(.confirm) }
        .onAppear { if viewModel.currentPassword.isEmpty { focused = .current } }
    }

    private var footer: some View {
        Button(buttonTitle, action: submit)
            .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading, isPill: true))
            .disabled(viewModel.isLoading || viewModel.isLocked)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(AppColor.background)
    }

    private var buttonTitle: String {
        if viewModel.isLocked { return "Tạm khoá" }
        return viewModel.isLoading ? "Đang gửi mã…" : "Tiếp tục"
    }

    private func submit() {
        focused = nil
        Task { await viewModel.submit() }
    }
}

// MARK: - Bước 2

private struct ChangePasswordVerifyStep: View {
    let viewModel: ChangePasswordViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(AppColor.brand, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: AppColor.brand.opacity(0.3), radius: 14, y: 8)
                    .padding(.top, 28)
                    .accessibilityHidden(true)

                Text("Xác minh email")
                    .font(.title.bold())
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)

                (Text("Để bảo vệ tài khoản, nhập mã \(ChangePasswordUseCase.codeLength) số đã gửi tới\n")
                    + Text(viewModel.email).fontWeight(.semibold).foregroundColor(AppColor.textPrimary))
                    .font(.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)

                OTPCodeField(code: viewModel.code, length: ChangePasswordUseCase.codeLength, onChange: viewModel.updateCode)
                    .padding(.top, 20)

                if let error = viewModel.codeError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(AppColor.danger)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await viewModel.resendCode() }
                    } label: {
                        Label(viewModel.resendTitle, systemImage: "arrow.clockwise").monospacedDigit()
                    }
                    .buttonStyle(ChipButtonStyle())
                    .disabled(!viewModel.canResend)

                    Button("Mở Mail") {
                        if let url = URL(string: "message://") { openURL(url) }
                    }
                    .buttonStyle(ChipButtonStyle())
                }
                .padding(.top, 12)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color(.systemOrange))
                        .accessibilityHidden(true)
                    Text("Không phải bạn yêu cầu đổi mật khẩu? Đừng chia sẻ mã này với bất kỳ ai và hãy bấm Quay lại.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color(.systemOrange).opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .onChange(of: viewModel.code) { _, code in
            if code.count == ChangePasswordUseCase.codeLength {
                Task { await viewModel.verify() }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Không thấy email? Kiểm tra thư mục Spam. \(viewModel.codeValidityText)")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            Button(viewModel.isLoading ? "Đang xác nhận…" : "Xác nhận đổi mật khẩu") {
                Task { await viewModel.verify() }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading, isPill: true))
            .disabled(!viewModel.canVerify)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(AppColor.background)
    }
}

// MARK: - Xong

private struct ChangePasswordDoneStep: View {
    let viewModel: ChangePasswordViewModel
    let onClose: () -> Void
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 104))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, AppColor.success)
                .symbolEffect(.bounce, value: isAnimating)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Đã đổi mật khẩu")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Lần sau đăng nhập, hãy dùng mật khẩu mới của bạn.")
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            GroupedCard {
                DeviceRow(
                    systemImage: "iphone",
                    tint: Color(.systemGreen),
                    title: "Thiết bị này",
                    subtitle: "Vẫn đăng nhập, không cần làm gì thêm"
                )
                GroupedDivider()
                DeviceRow(
                    systemImage: "laptopcomputer.and.iphone",
                    tint: Color(.systemOrange),
                    title: "Thiết bị khác",
                    subtitle: otherDevicesText
                )
            }
            .padding(.top, 16)

            Spacer()

            Button("Xong", action: onClose)
                .buttonStyle(PrimaryButtonStyle(isPill: true))
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .navigationBarBackButtonHidden()
        .onAppear { isAnimating = true }
    }

    private var otherDevicesText: String {
        guard let result = viewModel.result, result.loggedOutOtherDevices else {
            return "Vẫn đăng nhập như cũ"
        }
        if result.revokedSessionCount > 0 {
            return "Đã đăng xuất \(result.revokedSessionCount) thiết bị, cần đăng nhập lại bằng mật khẩu mới"
        }
        return "Không có thiết bị nào khác đang đăng nhập"
    }
}

// MARK: - Thành phần nhỏ

private struct SectionTitle: View {
    let title: String
    var uppercase = true

    init(_ title: String, uppercase: Bool = true) {
        self.title = title
        self.uppercase = uppercase
    }

    var body: some View {
        Text(uppercase ? title.uppercased() : title)
            .font(.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.leading, 20)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ErrorText: View {
    let message: String?

    init(_ message: String?) {
        self.message = message
    }

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(AppColor.danger)
                .padding(.horizontal, 20)
                .padding(.top, 2)
        }
    }
}

private struct StrengthRow: View {
    let strength: PasswordStrength

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Độ mạnh").foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(title).fontWeight(.semibold).foregroundStyle(color)
            }
            .font(.footnote)
            ProgressView(value: progress)
                .tint(color)
                .animation(.easeOut(duration: 0.2), value: strength)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Độ mạnh mật khẩu: \(title)")
    }

    private var title: String {
        switch strength {
        case .empty: return "—"
        case .weak: return "Yếu"
        case .medium: return "Trung bình"
        case .strong: return "Mạnh"
        }
    }

    private var color: Color {
        switch strength {
        case .empty: return AppColor.textTertiary
        case .weak: return AppColor.danger
        case .medium: return Color(.systemOrange)
        case .strong: return AppColor.success
        }
    }

    private var progress: Double {
        switch strength {
        case .empty: return 0
        case .weak: return 0.25
        case .medium: return 0.6
        case .strong: return 1
        }
    }
}

private struct RequirementRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isMet ? AppColor.success : AppColor.textTertiary)
                .contentTransition(.symbolEffect(.replace))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(isMet ? AppColor.textPrimary : AppColor.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isMet ? "Đạt" : "Chưa đạt")
    }
}

private struct DeviceRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: systemImage, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
    }
}

/// Nút viên thuốc nhỏ nền xám (Gửi lại mã, Mở Mail).
private struct ChipButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? AppColor.brand : AppColor.textSecondary)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(AppColor.field, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
            .frame(minHeight: 44)
    }
}
