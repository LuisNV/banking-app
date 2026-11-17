import SwiftUI

/// Nội dung drawer bên trái: tiện ích dùng được khi chưa đăng nhập.
struct UtilitiesDrawerView: View {
    let viewModel: UtilitiesViewModel
    let topInset: CGFloat
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    utilitiesList
                    if let support = viewModel.support {
                        supportSection(support)
                    }
                    Text("Phiên bản \(Bundle.main.appVersion)")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.leading, 12)
                }
                .padding(16)
            }
        }
        .task { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 10) {
                    BrandLogo(size: 36, style: .onBrand)
                    Text("Ngân hàng Số")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                CircleIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: "Đóng menu",
                    foreground: .white,
                    background: .white.opacity(0.18),
                    size: 36,
                    action: onClose
                )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Tiện ích")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Dùng ngay, không cần đăng nhập")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, topInset + 12)
        .padding(.bottom, 20)
        .background(AppColor.brand)
    }

    private var utilitiesList: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider().padding(.leading, 56)
                }
                Button {
                    viewModel.select(item)
                } label: {
                    UtilityRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .background(AppColor.card, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
    }

    private func supportSection(_ support: SupportContact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HỖ TRỢ KHÁCH HÀNG")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
                .padding(.leading, 12)

            HStack(spacing: 12) {
                IconTile(systemImage: "phone.fill", tint: Color(.systemGreen))
                VStack(alignment: .leading, spacing: 2) {
                    Text(support.title).font(.body.weight(.semibold))
                    Text(support.hotline).font(.footnote).foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
                if let url = support.phoneURL {
                    Link(destination: url) {
                        Text("Gọi")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(AppColor.brand, in: Capsule())
                    }
                    .accessibilityLabel("Gọi \(support.title)")
                }
            }
            .padding(12)
            .background(AppColor.card, in: RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous))
        }
    }
}

private struct UtilityRow: View {
    let item: UtilityItem

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemImage: item.kind.systemImage, tint: item.kind.tint)
            Text(item.title)
                .font(.body)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .contentShape(Rectangle())
    }
}

/// Ô icon màu kiểu Cài đặt iOS.
struct IconTile: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Màn hình tạm cho từng tiện ích. TODO: tách thành feature riêng khi làm thật.
struct UtilityDetailPlaceholderView: View {
    let item: UtilityItem

    var body: some View {
        VStack(spacing: 16) {
            IconTile(systemImage: item.kind.systemImage, tint: item.kind.tint)
                .scaleEffect(1.6)
                .padding(.top, 32)
            Text(item.title).font(.title3.bold())
            Text("Tính năng đang được phát triển.")
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
