import SwiftUI

/// Tiêu đề nhóm kiểu iOS ("TÀI KHOẢN").
struct ProfileSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.leading, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Nội dung một dòng cài đặt: ô biểu tượng + tiêu đề + giá trị + mũi tên.
struct ProfileRowLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    var value: String?
    var showsChevron = true

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: systemImage, tint: tint)
            Text(title)
                .font(.body)
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value)
                    .font(.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

/// Dòng có công tắc bật/tắt.
struct ProfileToggleRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    @Binding var isOn: Bool
    var isDisabled = false

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: systemImage, tint: tint)
            Toggle(title, isOn: $isOn)
                .tint(AppColor.success)
                .disabled(isDisabled)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }
}

/// Ô số liệu trong thẻ thống kê 3 cột.
struct ProfileStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
