import SwiftUI

/// Bước 3: nhập mã 6 số gửi tới email. Đủ 6 số thì tự xác minh.
struct RegisterVerifyStep: View {
    @Bindable var viewModel: RegisterViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                mailIcon
                    .padding(.top, 28)

                Text("Kiểm tra email")
                    .font(.title.bold())
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)

                (Text("Nhập mã \(RegisterUseCase.codeLength) số đã gửi tới\n")
                    + Text(viewModel.normalizedEmail).fontWeight(.semibold).foregroundColor(AppColor.textPrimary))
                    .font(.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)

                OTPCodeField(code: viewModel.code, onChange: viewModel.updateCode)
                    .padding(.top, 20)

                HStack(spacing: 10) {
                    Button {
                        Task { await viewModel.resendCode() }
                    } label: {
                        Label(viewModel.resendTitle, systemImage: "arrow.clockwise")
                            .monospacedDigit()
                    }
                    .buttonStyle(CapsuleChipStyle())
                    .disabled(!viewModel.canResend)

                    Button("Mở Mail") {
                        if let url = URL(string: "message://") { openURL(url) }
                    }
                    .buttonStyle(CapsuleChipStyle())
                }
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .sheet(isPresented: $viewModel.isShowingChangeEmail) {
            ChangeEmailSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.code) { _, code in
            if code.count == RegisterUseCase.codeLength {
                Task { await viewModel.verify() }
            }
        }
    }

    private var mailIcon: some View {
        Image(systemName: "envelope.fill")
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 84, height: 84)
            .background(AppColor.brand, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppColor.brand.opacity(0.3), radius: 14, y: 8)
            .accessibilityHidden(true)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Không thấy email? Kiểm tra thư mục Spam. \(viewModel.codeValidityText)")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)

            Button(viewModel.isLoading ? "Đang xác minh…" : "Xác minh") {
                Task { await viewModel.verify() }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading, isPill: true))
            .disabled(!viewModel.canVerify)

            Button("Đổi địa chỉ email") { viewModel.showChangeEmail() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.brand)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(AppColor.background)
    }
}

/// Nút viên thuốc nhỏ nền xám (Gửi lại mã, Mở Mail).
private struct CapsuleChipStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? AppColor.brand : AppColor.textSecondary)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(AppColor.fieldBackground, in: Capsule())
            .overlay(Capsule().strokeBorder(AppColor.fieldBorder, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
            .frame(minHeight: 44)
    }
}

/// Bottom sheet đổi địa chỉ email nhận mã (`PUT /registrations/{id}/email`).
private struct ChangeEmailSheet: View {
    @Bindable var viewModel: RegisterViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Đổi địa chỉ email")
                        .font(.title3.bold())
                    Text("Mã xác minh mới sẽ được gửi ngay tới email này.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                CircleIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: "Đóng",
                    foreground: AppColor.textSecondary,
                    size: 32,
                    action: { viewModel.isShowingChangeEmail = false }
                )
                .disabled(viewModel.isChangingEmail)
            }

            VStack(alignment: .leading, spacing: 6) {
                FormField(
                    "Email mới",
                    text: $viewModel.newEmail,
                    status: viewModel.changeEmailError == nil ? .none : .invalid,
                    textContentType: .emailAddress,
                    keyboardType: .emailAddress,
                    submitLabel: .send,
                    onSubmit: submit,
                    isFocused: isFocused
                )
                .focused($isFocused)
                if let error = viewModel.changeEmailError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(AppColor.danger)
                        .padding(.horizontal, 4)
                }
            }

            Button(viewModel.isChangingEmail ? "Đang gửi mã…" : "Gửi mã tới email mới", action: submit)
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isChangingEmail, isPill: true))
                .disabled(!viewModel.canSubmitNewEmail)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .interactiveDismissDisabled(viewModel.isChangingEmail)
        .onAppear { isFocused = true }
    }

    private func submit() {
        Task { await viewModel.submitNewEmail() }
    }
}
