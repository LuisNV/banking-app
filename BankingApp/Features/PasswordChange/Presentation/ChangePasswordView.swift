import SwiftUI

/// Đổi mật khẩu: mở toàn màn hình từ tab Cá nhân (che thanh tab), có NavigationStack riêng.
struct ChangePasswordView: View {
    // Tạo ViewModel ngay trong @State (không dùng giá trị mặc định của tham số init:
    // ViewModel thuộc MainActor nên tạo ở đó dễ báo lỗi biên dịch).
    /// Email/SĐT của tài khoản, điền sẵn khi bấm "Quên mật khẩu?".
    var accountIdentifier: String?
    /// Đặt lại mật khẩu xong (mọi phiên đã bị thu hồi): bên ngoài đưa về màn đăng nhập.
    var onPasswordReset: (String) -> Void = { _ in }

    @State private var viewModel = ChangePasswordViewModel()
    @State private var isShowingForgotPassword = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .form:
                    ChangePasswordFormStep(viewModel: viewModel, onForgotPassword: { isShowingForgotPassword = true })
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
        .fullScreenCover(isPresented: $isShowingForgotPassword) {
            ForgotPasswordView(identifier: accountIdentifier) { identifier in
                dismiss()
                onPasswordReset(identifier)
            }
        }
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
    let onForgotPassword: () -> Void
    @FocusState private var focused: PasswordChangeField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                FormSectionTitle("Mật khẩu hiện tại")
                GroupedCard {
                    FormFieldRow(
                        "Mật khẩu hiện tại",
                        systemImage: "lock.fill",
                        tint: Color(.systemGray),
                        text: binding(\.currentPassword, field: .current),
                        status: viewModel.status(for: .current),
                        isSecure: true,
                        isRevealed: $viewModel.isCurrentRevealed,
                        textContentType: .password,
                        onSubmit: { focused = .new }
                    )
                    .focused($focused, equals: .current)
                    .disabled(viewModel.isLocked)
                }
                FormErrorText(viewModel.error(for: .current))
                HStack {
                    Spacer()
                    Button("Quên mật khẩu?", action: onForgotPassword)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.brand)
                        .frame(minHeight: 44)
                        .padding(.trailing, 8)
                }

                FormSectionTitle("Mật khẩu mới").padding(.top, 14)
                GroupedCard {
                    FormFieldRow(
                        "Mật khẩu mới",
                        systemImage: "key.fill",
                        tint: AppColor.brand,
                        text: binding(\.newPassword, field: .new),
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
                        text: binding(\.confirmPassword, field: .confirm),
                        status: viewModel.status(for: .confirm),
                        isSecure: true,
                        isRevealed: $viewModel.isNewRevealed,
                        textContentType: .newPassword,
                        submitLabel: .go,
                        onSubmit: submit
                    )
                    .focused($focused, equals: .confirm)

                    GroupedDivider(leadingInset: 16)
                    PasswordStrengthRow(strength: viewModel.passwordEvaluation.strength)
                }
                FormErrorText(viewModel.error(for: .new))
                FormErrorText(viewModel.error(for: .confirm))

                FormSectionTitle("Yêu cầu", uppercase: false).padding(.top, 14)
                GroupedCard {
                    let evaluation = viewModel.passwordEvaluation
                    PasswordRequirementRow(text: "Ít nhất \(PasswordEvaluation.minimumLength) ký tự", isMet: evaluation.hasMinimumLength)
                    PasswordRequirementRow(text: "Chữ hoa và chữ thường", isMet: evaluation.hasUpperAndLowercase)
                    PasswordRequirementRow(text: "Ít nhất 1 chữ số", isMet: evaluation.hasDigit)
                    PasswordRequirementRow(text: "Khác mật khẩu hiện tại", isMet: viewModel.isDifferentFromCurrent)
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

    /// Chỉ khi NGƯỜI DÙNG gõ mới bỏ lỗi server của ô đó. (Dùng `.onChange` thì cả lúc ViewModel
    /// tự xoá ô sau lỗi "sai mật khẩu" cũng bị tính, làm câu "Bạn còn N lần thử" biến mất ngay.)
    private func binding(
        _ keyPath: ReferenceWritableKeyPath<ChangePasswordViewModel, String>,
        field: PasswordChangeField
    ) -> Binding<String> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { newValue in
                viewModel[keyPath: keyPath] = newValue
                viewModel.didEdit(field)
            }
        )
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

                Text("Để bảo vệ tài khoản, nhập mã \(ChangePasswordUseCase.codeLength) số đã gửi tới\n\(emailText)")
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
                    .buttonStyle(PillChipButtonStyle())
                    .disabled(!viewModel.canResend)

                    Button("Mở Mail") {
                        if let url = URL(string: "message://") { openURL(url) }
                    }
                    .buttonStyle(PillChipButtonStyle())
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

    private var emailText: Text {
        Text(viewModel.email).fontWeight(.semibold).foregroundColor(AppColor.textPrimary)
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
