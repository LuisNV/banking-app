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
            VStack(alignment: .leading, spacing: 8) {
                contactCard
                fieldErrors([.fullName, .phone, .email])
                if viewModel.isChangingEmail {
                    GroupedFooter(text: "Đổi email cần nhập mật khẩu hiện tại. Email mới sẽ cần xác minh lại.")
                }

                addressCard.padding(.top, 12)
                fieldErrors([.address])

                personalCard.padding(.top, 12)
                fieldErrors([.birthDate])
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
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
        .alert(
            "Không thể lưu",
            isPresented: $viewModel.isShowingAlert,
            presenting: viewModel.alertMessage
        ) { _ in
            Button("Đóng", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }

    // MARK: Sections

    private var contactCard: some View {
        GroupedCard {
            FormFieldRow(
                "Họ và tên",
                systemImage: "person.fill",
                tint: Color(.systemBlue),
                text: binding(\.fullName, field: .fullName),
                status: viewModel.status(for: .fullName),
                textContentType: .name,
                autocapitalization: .words,
                onSubmit: { focusedField = .phone }
            )
            .focused($focusedField, equals: .fullName)

            GroupedDivider()

            FormFieldRow(
                "Số điện thoại",
                systemImage: "phone.fill",
                tint: Color(.systemGreen),
                text: binding(\.phone, field: .phone),
                status: viewModel.status(for: .phone),
                textContentType: .telephoneNumber,
                keyboardType: .phonePad
            )
            .focused($focusedField, equals: .phone)

            GroupedDivider()

            FormFieldRow(
                "Email",
                systemImage: "envelope.fill",
                tint: Color(.systemIndigo),
                text: binding(\.email, field: .email),
                status: viewModel.status(for: .email),
                textContentType: .emailAddress,
                keyboardType: .emailAddress,
                onSubmit: { focusedField = .address }
            )
            .focused($focusedField, equals: .email)
        }
    }

    private var addressCard: some View {
        GroupedCard {
            HStack(alignment: .top, spacing: 14) {
                IconTile(systemImage: "house.fill", tint: Color(.systemOrange))
                    .padding(.top, 11)
                TextField("Địa chỉ", text: binding(\.address, field: .address), axis: .vertical)
                    .lineLimit(1...4)
                    .textContentType(.fullStreetAddress)
                    .focused($focusedField, equals: .address)
                    .padding(.vertical, 15)
                if viewModel.status(for: .address) == .invalid {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColor.danger)
                        .padding(.top, 14)
                        .accessibilityLabel("Chưa hợp lệ")
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var personalCard: some View {
        GroupedCard {
            HStack(spacing: 14) {
                IconTile(systemImage: "person.2.fill", tint: Color(.systemPurple))
                Text("Giới tính")
                Spacer()
                Picker("Giới tính", selection: $viewModel.gender) {
                    Text("Chưa chọn").tag(UserProfile.Gender?.none)
                    ForEach(UserProfile.Gender.allCases, id: \.self) { gender in
                        Text(gender.title).tag(UserProfile.Gender?.some(gender))
                    }
                }
                .labelsHidden()
                .tint(AppColor.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)

            GroupedDivider()

            HStack(spacing: 14) {
                IconTile(systemImage: "calendar", tint: Color(.systemRed))
                if let birthDate = viewModel.birthDate {
                    DatePicker(
                        "Ngày sinh",
                        selection: Binding(
                            get: { birthDate },
                            set: { viewModel.birthDate = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .tint(AppColor.brand)
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
                } else {
                    Text("Ngày sinh")
                    Spacer()
                    Button("Thêm") {
                        viewModel.birthDate = Calendar.current.date(byAdding: .year, value: -18, to: Date())
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
        }
    }

    @ViewBuilder
    private func fieldErrors(_ fields: [ProfileField]) -> some View {
        let messages = fields.compactMap { viewModel.error(for: $0) }
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(messages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(AppColor.danger)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
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
                GroupedCard {
                    FormFieldRow(
                        "Mật khẩu hiện tại",
                        systemImage: "lock.fill",
                        tint: Color(.systemGray),
                        text: $viewModel.currentPassword,
                        status: viewModel.passwordError == nil ? .none : .invalid,
                        isSecure: true,
                        isRevealed: $viewModel.isPasswordRevealed,
                        textContentType: .password,
                        submitLabel: .done,
                        onSubmit: confirm
                    )
                    .focused($isFocused)
                }
                if let error = viewModel.passwordError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(AppColor.danger)
                        .padding(.horizontal, 4)
                }
            }

            Button("Xác nhận", action: confirm)
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isSaving, isPill: true))
                .disabled(viewModel.isSaving || viewModel.currentPassword.isEmpty)
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
