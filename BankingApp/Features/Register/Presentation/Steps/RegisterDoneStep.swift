import SwiftUI

/// Bước 4: đăng ký thành công.
struct RegisterDoneStep: View {
    let viewModel: RegisterViewModel
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
                Text("Xong rồi!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Chào mừng \(displayName) đến với TingTing.\nTài khoản của bạn đã sẵn sàng.")
                    .font(.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            GroupedCard {
                HStack(spacing: 14) {
                    IconTile(systemImage: "envelope.fill", color: Color(.systemIndigo))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Email đã xác minh").font(.body)
                        Text(viewModel.normalizedEmail)
                            .font(.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColor.success)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 60)
                .accessibilityElement(children: .combine)
            }
            .padding(.top, 16)

            Spacer()

            Button("Đăng nhập ngay", action: viewModel.finish)
                .buttonStyle(PrimaryButtonStyle(isPill: true))
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onAppear { isAnimating = true }
    }

    private var displayName: String {
        let name = viewModel.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "bạn" : name
    }
}
