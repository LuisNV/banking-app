import SwiftUI

extension VocabStatus {
    var title: String {
        switch self {
        case .notStarted: return "Chưa học"
        case .learning: return "Đang học"
        case .known: return "Đã thuộc"
        }
    }

    var color: Color {
        switch self {
        case .notStarted: return Color(hex: 0xD5DAE3)
        case .learning: return Color(.systemOrange)
        case .known: return AppColor.success
        }
    }

    /// Màu chữ đậm hơn để đọc được trên nền nhạt.
    var textColor: Color {
        switch self {
        case .notStarted: return AppColor.textSecondary
        case .learning: return Color(hex: 0x9A3A00)
        case .known: return Color(hex: 0x1E7A37)
        }
    }

    var tintBackground: Color {
        switch self {
        case .notStarted: return AppColor.rowDivider
        case .learning: return Color(hex: 0xFFF1E3)
        case .known: return Color(hex: 0xE9F8EE)
        }
    }
}

/// Chấm tròn trạng thái học.
struct VocabStatusDot: View {
    let status: VocabStatus
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Nhãn trạng thái dạng viên thuốc ("● Đang học").
struct VocabStatusBadge: View {
    let status: VocabStatus

    var body: some View {
        HStack(spacing: 6) {
            VocabStatusDot(status: status, size: 7)
            Text(status.title)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(status.textColor)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Capsule().fill(status.tintBackground))
    }
}

/// Nút loa tròn viền mảnh (hoặc tô màu khi `filled`).
struct SpeakerButton: View {
    var size: CGFloat = 40
    var filled = false
    var accessibilityLabel = "Nghe phát âm"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(filled ? .white : AppColor.brand)
                .frame(width: size, height: size)
                .background(Circle().fill(filled ? AppColor.brand : AppColor.fieldBackground))
                .overlay {
                    if !filled { Circle().strokeBorder(AppColor.cardBorder, lineWidth: 1.5) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Chip chọn một giá trị (bộ lọc, số câu…): viền xám, khi chọn thì viền và chữ xanh.
struct SelectableChipStyle: ButtonStyle {
    let isSelected: Bool
    var height: CGFloat = 32
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isSelected ? AppColor.brand : AppColor.textPrimary)
            .padding(.horizontal, 12)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(height: height)
            .background(Capsule().fill(isSelected ? AppColor.brandTint : AppColor.fieldBackground))
            .overlay {
                Capsule().strokeBorder(isSelected ? AppColor.brand : AppColor.cardBorder, lineWidth: isSelected ? 2 : 1.5)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

extension Font {
    /// Chữ Hán: dùng font hệ thống (PingFang) với cỡ cố định.
    static func hanzi(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }
}

/// Một dòng chiết tự: ô chữ lớn, nhãn bố cục ("Trái/phải"), công thức bộ phận và câu gợi nhớ.
struct DecompositionRow: View {
    let item: CharacterDecomposition

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.character)
                .font(.hanzi(32))
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColor.brandTint))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if let formula = item.formula {
                    if let layout = item.layout {
                        Text(layout)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.fieldLabel)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .overlay(Capsule().strokeBorder(AppColor.fieldBorder, lineWidth: 1))
                    }
                    Text(formula)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let mnemonic = item.mnemonic {
                        Text(mnemonic)
                            .font(.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    // Ghi chú không đúng mẫu "Bố cục [công thức] …": hiện nguyên văn.
                    Text(item.note)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chữ \(item.character): \(item.note)")
    }
}
