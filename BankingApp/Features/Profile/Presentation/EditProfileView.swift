import SwiftUI

/// Màn sửa thông tin cá nhân (`PUT v1/users/me`).
struct EditProfileView: View {
    @State private var viewModel: EditProfileViewModel
    @FocusState private var focusedField: ProfileField?
    @Environment(\.dismiss) private var dismiss

    init(viewModel: EditProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                field(.fullName) {
                    FormField(
                        "Họ và tên",
                        text: binding(\.fullName, field: .fullName),
                        status: viewModel.status(for: .fullName),
                        textContentType: .name,
                        autocapitalization: .words,
                        onSubmit: { focusedField = .phone },
                        isFocused: focusedField == .fullName
                    )
                    .focused($focusedField, equals: .fullName)
                }

                field(.phone) {
                    FormField(
                        "Số điện thoại",
                        text: binding(\.phone, field: .phone),
                        status: viewModel.status(for: .phone),
                        textContentType: .telephoneNumber,
                        keyboardType: .phonePad,
                        isFocused: focusedField == .phone
                    )
                    .focused($focusedField, equals: .phone)
                }

                field(.email) {
                    FormField(
                        "Email",
                        text: binding(\.email, field: .email),
                        status: viewModel.status(for: .email),
                        textContentType: .emailAddress,
                        keyboardType: .emailAddress,
                        onSubmit: { focusedField = .address },
                        isFocused: focusedField == .email
                    )
                    .focused($focusedField, equals: .email)
                    if viewModel.isChangingEmail {
                        Text("Đổi email cần nhập mật khẩu hiện tại. Email mới sẽ cần xác minh lại.")
                            .font(.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                            .padding(.horizontal, 2)
                    }
                }

                field(.address) {
                    FormField(
                        "Địa chỉ",
                        text: binding(\.address, field: .address),
                        status: viewModel.status(for: .address) == .invalid ? .invalid : .none,
                        textContentType: .fullStreetAddress,
                        autocapitalization: .sentences,
                        submitLabel: .return,
                        isMultiline: true,
                        isFocused: focusedField == .address
                    )
                    .focused($focusedField, equals: .address)
                }

                HStack(alignment: .top, spacing: 12) {
                    genderField
                    field(.birthDate) { birthDateField }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Sửa thông tin")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isSaving)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving && !viewModel.isShowingPasswordSheet {
                    ProgressView()
                } else {
                    Button("Lưu") {
                        focusedField = nil
                        Task { await viewModel.save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingPasswordSheet) {
            PasswordConfirmSheet(viewModel: viewModel)
        }
        .errorPopup(
            "Không thể lưu",
            isPresented: $viewModel.isShowingAlert,
            message: viewModel.alertMessage,
            retry: { Task { await viewModel.save() } }
        )
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }

    // MARK: Sections

    private var genderField: some View {
        FormFieldBox(label: "Giới tính") {
            Picker("Giới tính", selection: $viewModel.gender) {
                Text("Chưa chọn").tag(UserProfile.Gender?.none)
                ForEach(UserProfile.Gender.allCases, id: \.self) { gender in
                    Text(gender.title).tag(UserProfile.Gender?.some(gender))
                }
            }
            .labelsHidden()
            .tint(AppColor.textPrimary)
            .padding(.leading, -12)
        }
    }

    private var birthDateField: some View {
        FormFieldBox(label: "Ngày sinh", status: viewModel.status(for: .birthDate) == .invalid ? .invalid : .none) {
            if let birthDate = viewModel.birthDate {
                HStack(spacing: 0) {
                    DatePicker(
                        "Ngày sinh",
                        selection: Binding(
                            get: { birthDate },
                            set: { viewModel.birthDate = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .tint(AppColor.brand)
                    .padding(.leading, -6)
                    Spacer(minLength: 0)
                    Button {
                        viewModel.birthDate = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppColor.textTertiary)
                            .frame(width: 32, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Xoá ngày sinh")
                }
            } else {
                Button {
                    viewModel.birthDate = Calendar.current.date(byAdding: .year, value: -18, to: Date())
                } label: {
                    Label("Thêm", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColor.brand)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Thêm ngày sinh")
            }
        }
    }

    /// Ô nhập kèm dòng lỗi của server/kiểm tra (nếu có) ngay bên dưới.
    private func field<Content: View>(_ field: ProfileField, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
            FormErrorText(viewModel.error(for: field))
        }
    }

    /// Binding vào trường của ViewModel; sửa thì bỏ lỗi server cũ của trường đó.
    private func binding(_ keyPath: ReferenceWritableKeyPath<EditProfileViewModel, String>, field: ProfileField) -> Binding<String> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { newValue in
                viewModel[keyPath: keyPath] = newValue
                viewModel.didEdit(field)
            }
        )
    }
}

/// Bottom sheet hỏi mật khẩu hiện tại khi đổi email.
private struct PasswordConfirmSheet: View {
    @Bindable var viewModel: EditProfileViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Xác nhận mật khẩu")
                        .font(.title3.bold())
                    Text("Nhập mật khẩu hiện tại để đổi email sang **\(viewModel.newEmail)**.")
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
                    action: { viewModel.cancelPassword() }
                )
                .disabled(viewModel.isSaving)
            }

            VStack(alignment: .leading, spacing: 6) {
                FormField(
                    "Mật khẩu hiện tại",
                    text: $viewModel.currentPassword,
                    status: viewModel.passwordError == nil ? .none : .invalid,
                    isSecure: true,
                    isRevealed: $viewModel.isPasswordRevealed,
                    textContentType: .password,
                    submitLabel: .done,
                    onSubmit: confirm,
                    isFocused: isFocused
                )
                .focused($isFocused)
                .disabled(viewModel.isPasswordLocked)
                if let error = viewModel.passwordError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(AppColor.danger)
                        .padding(.horizontal, 4)
                }
            }

            Button(viewModel.isPasswordLocked ? "Tạm khoá" : "Xác nhận", action: confirm)
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isSaving, isPill: true))
                .disabled(!viewModel.canConfirmPassword)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .interactiveDismissDisabled(viewModel.isSaving)
        .onAppear { isFocused = true }
    }

    private func confirm() {
        Task { await viewModel.confirmPassword() }
    }
}
