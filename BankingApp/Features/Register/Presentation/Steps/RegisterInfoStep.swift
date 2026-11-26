import SwiftUI

/// Bước 1: họ tên, email, số điện thoại, ngày sinh.
struct RegisterInfoStep: View {
    @Bindable var viewModel: RegisterViewModel
    @FocusState private var focusedField: RegistrationField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                RegisterStepHeader(
                    title: "Tạo tài khoản",
                    subtitle: "Chỉ mất một phút để bắt đầu học cùng TingTing."
                )
                .padding(.bottom, 20)

                VStack(spacing: 16) {
                    FormField(
                        "Họ và tên",
                        text: $viewModel.fullName,
                        status: viewModel.status(for: .fullName),
                        textContentType: .name,
                        autocapitalization: .words,
                        onSubmit: { focusedField = .email },
                        isFocused: focusedField == .fullName
                    )
                    .focused($focusedField, equals: .fullName)

                    FormField(
                        "Email",
                        text: $viewModel.email,
                        status: viewModel.status(for: .email),
                        textContentType: .emailAddress,
                        keyboardType: .emailAddress,
                        onSubmit: { focusedField = .phone },
                        isFocused: focusedField == .email
                    )
                    .focused($focusedField, equals: .email)

                    FormField(
                        "Số điện thoại",
                        text: $viewModel.phone,
                        status: viewModel.status(for: .phone),
                        textContentType: .telephoneNumber,
                        keyboardType: .phonePad,
                        submitLabel: .done,
                        isFocused: focusedField == .phone
                    )
                    .focused($focusedField, equals: .phone)

                    FormFieldBox(label: "Ngày sinh") {
                        DatePicker(
                            "Ngày sinh",
                            selection: $viewModel.birthDate,
                            in: ...Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .tint(AppColor.brand)
                    }
                }

                GroupedFooter(text: "Giúp TingTing gợi ý lộ trình học phù hợp với bạn.")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        // Sửa ô nào thì bỏ lỗi "đã được dùng" của server ở ô đó.
        .onChange(of: viewModel.email) { _, _ in viewModel.didEdit(.email) }
        .onChange(of: viewModel.phone) { _, _ in viewModel.didEdit(.phone) }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(viewModel.isLoading ? "Đang kiểm tra…" : "Tiếp tục") {
                focusedField = nil
                Task { await viewModel.continueFromInfo() }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading, isPill: true))
            .disabled(viewModel.isLoading)

            HStack(spacing: 4) {
                Text("Đã có tài khoản?").foregroundStyle(AppColor.textSecondary)
                Button("Đăng nhập", action: viewModel.cancel)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.brand)
                    .frame(minHeight: 44)
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(AppColor.background)
    }
}
