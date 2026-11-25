import SwiftUI

/// Bottom sheet chọn nguồn ảnh đại diện: chụp ảnh hoặc chọn trong thư viện.
struct AvatarSourceSheet: View {
    enum Source { case camera, library }

    let isCameraAvailable: Bool
    let onSelect: (Source) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Đổi ảnh đại diện")
                    .font(.title3.bold())
                Spacer()
                CircleIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: "Đóng",
                    foreground: AppColor.textSecondary,
                    size: 32,
                    action: onCancel
                )
            }

            GroupedCard {
                optionRow(
                    title: "Chụp ảnh",
                    subtitle: isCameraAvailable ? nil : "Thiết bị không có camera",
                    systemImage: "camera.fill",
                    tint: Color(.systemBlue)
                ) { onSelect(.camera) }
                .disabled(!isCameraAvailable)

                GroupedDivider()

                optionRow(
                    title: "Chọn từ thư viện",
                    subtitle: nil,
                    systemImage: "photo.on.rectangle",
                    tint: Color(.systemGreen)
                ) { onSelect(.library) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .presentationDetents([.height(230)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private func optionRow(
        title: String,
        subtitle: String?,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconTile(systemImage: systemImage, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(AppColor.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
