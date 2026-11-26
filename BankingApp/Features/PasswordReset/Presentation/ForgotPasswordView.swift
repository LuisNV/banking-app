import SwiftUI

/// Quên mật khẩu (mở toàn màn hình từ màn Đăng nhập hoặc Đổi mật khẩu).
/// - Parameters:
///   - identifier: email/SĐT điền sẵn.
///   - onFinished: đặt lại xong, người dùng bấm "Đăng nhập" (nhận email/SĐT đã dùng).
struct ForgotPasswordView: View {
    let identifier: String?
    let onFinished: (String) -> Void

    @State private var viewModel = ForgotPasswordViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .identifier:
                    ForgotIdentifierStep(viewModel: viewModel, onClose: { dismiss() })
                case .verify:
                    ForgotVerifyStep(viewModel: viewModel)
                case .newPassword:
                    ForgotNewPasswordStep(viewModel: viewModel)
                case .done:
                    ForgotDoneStep(viewModel: viewModel) {
                        let used = LoginUseCase.normalizedIdentifier(viewModel.identifier)
                        dismiss()
                        onFinished(used)
                    }
                }
            }
            .transition(.opacity)
            .animation(.snappy(duration: 0.3), value: viewModel.step)
            .background(AppColor.background)
            .navigationTitle("Quên mật khẩu")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar { toolbar }
            .errorPopup(
                "Không thể đặt lại mật khẩu",
                isPresented: $viewModel.isShowingAlert,
                message: viewModel.alertMessage
            )
        }
        .interactiveDismissDisabled(viewModel.isLoading || viewModel.step == .done)
        .onAppear { viewModel.prefill(identifier) }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            switch viewModel.step {
            case .identifier:
                Button("Huỷ") { dismiss() }
                    .disabled(viewModel.isLoading)
            case .verify, .newPassword:
                Button {
                    viewModel.goBack()
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
                Text("\(viewModel.step.rawValue) / 3")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityLabel("Bước \(viewModel.step.rawValue) trên 3")
            }
        }
    }
}

// MARK: - Bước 1

private struct ForgotIdentifierStep: View {
    @Bindable var viewModel: ForgotPasswordViewModel
    let onClose: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForgotStepIcon(systemImage: "key.fill")
                    .padding(.top, 28)
                Text("Đặt lại mật khẩu")
                    .font(.title.bold())
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                Text("Nhập email hoặc số điện thoại của tài khoản. Mã xác minh sẽ được gửi tới email của bạn.")
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 6) {
                    GroupedCard {
                        FormFieldRow(
                            "Email / Số điện thoại",
                            systemImage: "person.fill",
                            tint: Color(.systemIndigo),
                            text: Binding(
                                get: { viewModel.identifier },
                                set: { viewModel.identifier = $0; viewModel.didEditIdentifier() }
                            ),
                            status: viewModel.identifierError == nil ? .none : .invalid,
                            textContentType: .username,
                            keyboardType: .emailAddress,
                            submitLabel: .send,
                            onSubmit: send
                        )
                        .focused($isFocused)
                    }
                    FormErrorText(viewModel.identifierError)
                    Text("Nhập số điện thoại thì mã vẫn được gửi tới email đã đăng ký với số đó.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                Button(viewModel.isLoading ? "Đang gửi mã…" : "Gửi mã", action: send)
                    .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading, isPill: true))
                    .disabled(!viewModel.canSendCode)
                Button("Quay lại đăng nhập", action: onClose)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.brand)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .background(AppColor.background)
        }
        .onAppear { if viewModel.identifier.isEmpty { isFocused = true } }
    }

    private func send() {
        isFocused = false
        Task { await viewModel.sendCode() }
    }
}

// MARK: - Bước 2

private struct ForgotVerifyStep: View {
    let viewModel: ForgotPasswordViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForgotStepIcon(systemImage: "envelope.fill")
                    .padding(.top, 28)
                Text("Kiểm tra email")
                    .font(.title.bold())
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                // Câu chữ không khẳng định tài khoản tồn tại (server cố ý không tiết lộ).
                Text("Nếu tài khoản tồn tại, mã \(ResetPasswordUseCase.codeLength) số đã được gửi tới\n\(destinationText)")
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)

                OTPCodeField(code: viewModel.code, length: ResetPasswordUseCase.codeLength, onChange: viewModel.updateCode)
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
                    .overlay {
                        // Mã cũ không dùng được nữa: viền nhấn để người dùng thấy nút gửi lại.
                        if viewModel.needsNewCode && viewModel.canResend {
                            Capsule().strokeBorder(AppColor.brand, lineWidth: 1.5).frame(height: 40)
                        }
                    }

                    Button("Mở Mail") {
                        if let url = URL(string: "message://") { openURL(url) }
                    }
                    .buttonStyle(PillChipButtonStyle())
                }
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                Text("Không thấy email? Kiểm tra thư mục Spam, hoặc kiểm tra lại email / số điện thoại vừa nhập. \(viewModel.codeValidityText)")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                Button(viewModel.isLoading ? "Đang xác minh…" : "Tiếp tục") {
                    Task { await viewModel.verify() }
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading, isPill: true))
                .disabled(!viewModel.canVerify)
                Button("Dùng email hoặc số điện thoại khác") { viewModel.goBack() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.brand)
                    .frame(minHeight: 44)
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .background(AppColor.background)
        }
        .onChange(of: viewModel.code) { _, code in
            if code.count == ResetPasswordUseCase.codeLength {
                Task { await viewModel.verify() }
            }
        }
    }

    private var destinationText: Text {
        Text(viewModel.destination).fontWeight(.semibold).foregroundColor(AppColor.textPrimary)
    }
}

// MARK: - Bước 3

private struct ForgotNewPasswordStep: View {
    @Bindable var viewModel: ForgotPasswordViewModel
    @FocusState private var focused: PasswordResetField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mật khẩu mới")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Email đã được xác minh. Hãy đặt mật khẩu bạn chưa dùng ở nơi khác.")
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 16)

                GroupedCard {
                    FormFieldRow(
                        "Mật khẩu mới",
                        systemImage: "key.fill",
                        tint: AppColor.brand,
                        text: binding(\.newPassword, field: .new),
                        status: viewModel.status(for: .new),
                        isSecure: true,
                        isRevealed: $viewModel.isPasswordRevealed,
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
                        isRevealed: $viewModel.isPasswordRevealed,
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
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color(.systemOrange))
                        .accessibilityHidden(true)
                    Text("Để bảo vệ tài khoản, mọi thiết bị đang đăng nhập sẽ bị đăng xuất sau khi đặt lại mật khẩu.")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color(.systemOrange).opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(viewModel.isLoading ? "Đang đặt lại…" : "Đặt lại mật khẩu", action: submit)
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading, isPill: true))
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppColor.background)
        }
        .onAppear { focused = .new }
    }

    private func submit() {
        focused = nil
        Task { await viewModel.complete() }
    }

    /// Chỉ khi người dùng gõ mới bỏ lỗi server của ô đó.
    private func binding(
        _ keyPath: ReferenceWritableKeyPath<ForgotPasswordViewModel, String>,
        field: PasswordResetField
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

// MARK: - Xong

private struct ForgotDoneStep: View {
    let viewModel: ForgotPasswordViewModel
    let onLogin: () -> Void
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
                Text("Đã đặt lại mật khẩu")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Hãy đăng nhập bằng mật khẩu mới để tiếp tục học.")
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            GroupedCard {
                ForgotInfoRow(
                    systemImage: "laptopcomputer.and.iphone",
                    tint: Color(.systemOrange),
                    title: "Mọi thiết bị đã đăng xuất",
                    subtitle: devicesText
                )
                if let email = viewModel.result?.notifiedEmail {
                    GroupedDivider()
                    ForgotInfoRow(
                        systemImage: "envelope.fill",
                        tint: Color(.systemIndigo),
                        title: "Đã gửi email thông báo",
                        subtitle: "tới \(email)"
                    )
                }
                if viewModel.result?.biometricDisabled ?? true {
                    GroupedDivider()
                    ForgotInfoRow(
                        systemImage: "faceid",
                        tint: Color(.systemGreen),
                        title: "Đăng nhập sinh trắc học tạm tắt",
                        subtitle: "Dùng lại được sau khi đăng nhập bằng mật khẩu mới"
                    )
                }
            }
            .padding(.top, 16)

            Spacer()

            Button("Đăng nhập", action: onLogin)
                .buttonStyle(PrimaryButtonStyle(isPill: true))
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onAppear { isAnimating = true }
    }

    private var devicesText: String {
        let count = viewModel.result?.revokedSessionCount ?? 0
        return count > 0 ? "Đã thu hồi \(count) phiên, kể cả máy này" : "Kể cả máy này, cần đăng nhập lại"
    }
}

// MARK: - Thành phần nhỏ

private struct ForgotStepIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 84, height: 84)
            .background(AppColor.brand, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppColor.brand.opacity(0.3), radius: 14, y: 8)
            .accessibilityHidden(true)
    }
}

private struct ForgotInfoRow: View {
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
