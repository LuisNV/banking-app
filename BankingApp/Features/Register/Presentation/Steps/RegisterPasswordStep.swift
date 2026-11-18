import SwiftUI

/// Bước 2: tạo mật khẩu, nhập lại, độ mạnh và danh sách yêu cầu.
struct RegisterPasswordStep: View {
    @Bindable var viewModel: RegisterViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case password, confirm }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                RegisterStepHeader(
                    title: "Tạo mật khẩu",
                    subtitle: "Dùng mật khẩu bạn chưa dùng ở nơi khác."
                )
                .padding(.bottom, 20)

                GroupedCard {
                    FormFieldRow(
                        "Mật khẩu",
                        systemImage: "lock.fill",
                        tint: Color(.systemGray),
                        text: $viewModel.password,
                        isSecure: true,
                        isRevealed: $viewModel.isPasswordVisible,
                        textContentType: .newPassword,
                        onSubmit: { focusedField = .confirm }
                    )
                    .focused($focusedField, equals: .password)

                    GroupedDivider()

                    FormFieldRow(
                        "Nhập lại mật khẩu",
                        systemImage: "lock.fill",
                        tint: Color(.systemGray),
                        text: $viewModel.confirmPassword,
                        status: viewModel.confirmStatus,
                        isSecure: true,
                        isRevealed: $viewModel.isPasswordVisible,
                        textContentType: .newPassword,
                        submitLabel: .go,
                        onSubmit: submit
                    )
                    .focused($focusedField, equals: .confirm)

                    GroupedDivider(leadingInset: 16)

                    strengthRow
                }

                if viewModel.confirmStatus == .invalid {
                    GroupedFooter(text: "Mật khẩu nhập lại chưa khớp.", isError: true)
                }

                Text("Yêu cầu")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                GroupedCard {
                    let evaluation = viewModel.passwordEvaluation
                    RequirementRow(text: "Ít nhất \(PasswordEvaluation.minimumLength) ký tự", isMet: evaluation.hasMinimumLength)
                    RequirementRow(text: "Chữ hoa và chữ thường", isMet: evaluation.hasUpperAndLowercase)
                    RequirementRow(text: "Ít nhất 1 chữ số", isMet: evaluation.hasDigit)
                    RequirementRow(text: "Ký tự đặc biệt (không bắt buộc)", isMet: evaluation.hasSpecialCharacter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .onAppear { focusedField = .password }
    }

    private var strengthRow: some View {
        let strength = viewModel.passwordEvaluation.strength
        return VStack(spacing: 8) {
            HStack {
                Text("Độ mạnh").foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(strength.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(strength.color)
            }
            .font(.footnote)

            ProgressView(value: strength.progress)
                .tint(strength.color)
                .animation(.easeOut(duration: 0.2), value: strength)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Độ mạnh mật khẩu: \(strength.title)")
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button(viewModel.isLoading ? "Đang tạo tài khoản…" : "Tạo tài khoản", action: submit)
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading, isPill: true))
                .disabled(!viewModel.canCreateAccount)

            Text("Khi tiếp tục, bạn đồng ý với [Điều khoản sử dụng](https://example.com/terms) và [Chính sách quyền riêng tư](https://example.com/privacy).")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                .tint(AppColor.brand)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(AppColor.background)
    }

    private func submit() {
        focusedField = nil
        Task { await viewModel.createAccount() }
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

private extension PasswordStrength {
    var title: String {
        switch self {
        case .empty: return "—"
        case .weak: return "Yếu"
        case .medium: return "Trung bình"
        case .strong: return "Mạnh"
        }
    }

    var color: Color {
        switch self {
        case .empty: return AppColor.textTertiary
        case .weak: return AppColor.danger
        case .medium: return Color(.systemOrange)
        case .strong: return AppColor.success
        }
    }

    var progress: Double {
        switch self {
        case .empty: return 0
        case .weak: return 0.25
        case .medium: return 0.6
        case .strong: return 1
        }
    }
}
