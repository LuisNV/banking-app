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

                GroupedCard {
                    FormFieldRow(
                        "Họ và tên",
                        systemImage: "person.fill",
                        tint: Color(.systemBlue),
                        text: $viewModel.fullName,
                        status: viewModel.status(for: .fullName),
                        textContentType: .name,
                        autocapitalization: .words,
                        onSubmit: { focusedField = .email }
                    )
                    .focused($focusedField, equals: .fullName)

                    GroupedDivider()

                    FormFieldRow(
                        "Email",
                        systemImage: "envelope.fill",
                        tint: Color(.systemIndigo),
                        text: $viewModel.email,
                        status: viewModel.status(for: .email),
                        textContentType: .emailAddress,
                        keyboardType: .emailAddress,
                        onSubmit: { focusedField = .phone }
                    )
                    .focused($focusedField, equals: .email)

                    GroupedDivider()

                    FormFieldRow(
                        "Số điện thoại",
                        systemImage: "phone.fill",
                        tint: Color(.systemGreen),
                        text: $viewModel.phone,
                        status: viewModel.status(for: .phone),
                        textContentType: .telephoneNumber,
                        keyboardType: .phonePad,
                        submitLabel: .done
                    )
                    .focused($focusedField, equals: .phone)
                }

                GroupedCard {
                    HStack(spacing: 14) {
                        IconTile(systemImage: "calendar", color: Color(.systemRed))
                        DatePicker(
                            "Ngày sinh",
                            selection: $viewModel.birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .tint(AppColor.brand)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                }
                .padding(.top, 12)

                GroupedFooter(text: "Giúp TingTing gợi ý lộ trình học phù hợp với bạn.")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button("Tiếp tục") {
                focusedField = nil
                viewModel.continueFromInfo()
            }
            .buttonStyle(PrimaryButtonStyle(isPill: true))

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
