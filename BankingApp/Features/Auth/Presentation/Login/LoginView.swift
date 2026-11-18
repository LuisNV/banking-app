import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    @State private var utilitiesViewModel = UtilitiesViewModel()
    private let onRegister: () -> Void
    @FocusState private var focusedField: Field?

    private enum Field { case username, password }

    init(viewModel: LoginViewModel, onRegister: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.onRegister = onRegister
    }

    var body: some View {
        SideDrawer(isOpen: $viewModel.isDrawerOpen) {
            content
        } drawer: { insets in
            UtilitiesDrawerView(
                viewModel: utilitiesViewModel,
                topInset: insets.top,
                onClose: { viewModel.isDrawerOpen = false }
            )
        }
        .onAppear { viewModel.onAppear() }
        .onChange(of: viewModel.isDrawerOpen) { _, isOpen in
            if isOpen { focusedField = nil }
        }
        .alert(
            "Không thể đăng nhập",
            isPresented: $viewModel.isShowingError,
            presenting: viewModel.errorMessage
        ) { _ in
            Button("Đóng", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .sheet(item: $utilitiesViewModel.selectedItem) { item in
            UtilityDetailPlaceholderView(item: item)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Sections

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                form
            }
            .padding(.horizontal, AppMetrics.screenPadding)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(AppColor.background)
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(
                systemImage: "line.3.horizontal",
                accessibilityLabel: "Mở menu học thử",
                action: viewModel.toggleDrawer
            )

            Spacer()

            Menu {
                Button("Tiếng Việt") {}
                Button("English") {}
            } label: {
                Label("Tiếng Việt", systemImage: "globe")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(AppColor.field, in: Capsule())
            }
            .accessibilityLabel("Đổi ngôn ngữ")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(AppColor.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            BrandLogo()
            VStack(alignment: .leading, spacing: 8) {
                Text("Chào mừng đến\nTingTing")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColor.textPrimary)
                Text("Đăng nhập để tiếp tục học tiếng Trung")
                    .font(.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private var form: some View {
        VStack(spacing: 12) {
            AppTextField(
                "Email / Số điện thoại",
                systemImage: "person",
                text: $viewModel.username,
                textContentType: .username,
                submitLabel: .next,
                onSubmit: { focusedField = .password }
            )
            .focused($focusedField, equals: .username)

            AppTextField(
                "Mật khẩu",
                systemImage: "lock",
                text: $viewModel.password,
                isSecure: true,
                isRevealed: $viewModel.isPasswordVisible,
                textContentType: .password,
                submitLabel: .go,
                onSubmit: submit
            )
            .focused($focusedField, equals: .password)

            HStack {
                Toggle(isOn: $viewModel.rememberMe) {
                    Text("Ghi nhớ").font(.subheadline)
                }
                .toggleStyle(.switch)
                .tint(AppColor.success)
                .fixedSize()

                Spacer()

                Button("Quên mật khẩu?") {
                    // TODO: điều hướng tới luồng khôi phục mật khẩu.
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.brand)
                .frame(minHeight: 44)
            }

            Button(viewModel.isLoading ? "Đang đăng nhập…" : "Đăng nhập", action: submit)
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading))
                .disabled(!viewModel.canSubmit)
                .padding(.top, 4)

            if viewModel.showsBiometricButton {
                orDivider

                Button {
                    focusedField = nil
                    Task { await viewModel.loginWithBiometrics() }
                } label: {
                    Label(
                        viewModel.biometricType.loginTitle,
                        systemImage: viewModel.biometricType.systemImage
                    )
                }
                .buttonStyle(TintedButtonStyle())
                .disabled(viewModel.isLoading)
            }
        }
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(AppColor.separator).frame(height: 0.5)
            Text("hoặc").font(.footnote).foregroundStyle(AppColor.textSecondary)
            Rectangle().fill(AppColor.separator).frame(height: 0.5)
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("Chưa có tài khoản?").foregroundStyle(AppColor.textSecondary)
                Button("Đăng ký", action: onRegister)
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.brand)
            }
            .font(.subheadline)

            HStack(spacing: 4) {
                Link("Điều khoản", destination: URL(string: "https://example.com/terms")!)
                Text("·")
                Link("Quyền riêng tư", destination: URL(string: "https://example.com/privacy")!)
            }
            .font(.caption)
            .underline()
            .foregroundStyle(AppColor.textSecondary)
            .tint(AppColor.textSecondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(AppColor.background)
    }

    private func submit() {
        focusedField = nil
        Task { await viewModel.login() }
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel(onAuthenticated: { _ in }))
}
