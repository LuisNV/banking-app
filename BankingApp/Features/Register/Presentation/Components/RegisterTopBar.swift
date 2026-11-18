import SwiftUI

/// Thanh trên của luồng đăng ký: nút quay lại tròn, tiêu đề giữa, nhãn bước "1 / 3".
struct RegisterTopBar: View {
    let stepNumber: Int
    let stepCount: Int
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text("Đăng ký")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(AppColor.separator.opacity(0.4), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quay lại")

                Spacer()

                Text("\(stepNumber) / \(stepCount)")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(AppColor.field, in: Capsule())
                    .accessibilityLabel("Bước \(stepNumber) trên \(stepCount)")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }
}

/// Tiêu đề lớn + mô tả ở đầu mỗi bước.
struct RegisterStepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textPrimary)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Dòng chú thích nhỏ dưới thẻ (lỗi màu đỏ hoặc gợi ý màu xám).
struct GroupedFooter: View {
    let text: String
    var isError = false

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(isError ? AppColor.danger : AppColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
}
