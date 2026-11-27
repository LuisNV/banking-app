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

/// Một dòng chiết tự: ô chữ lớn kèm âm Hán Việt, các bộ phận ghép bằng "+", câu gợi nhớ (tô đậm từ khóa).
struct DecompositionRow: View {
    let item: CharacterDecomposition

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(item.character)
                    .font(.hanzi(32))
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColor.brandTint))
                if let hanViet = item.hanViet {
                    Text(hanViet.capitalizedFirstLetter)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.brand)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                if !item.components.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(Array(item.components.enumerated()), id: \.offset) { offset, component in
                            if offset > 0 {
                                Text("+")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColor.textTertiary)
                                    .frame(height: 32)
                            }
                            ComponentChip(component: component)
                        }
                    }
                } else if let formula = item.formula {
                    if let layout = item.layout {
                        Text(layout)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.fieldLabel)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .overlay(Capsule().strokeBorder(AppColor.fieldBorder, lineWidth: 1))
                    }
                    Text(formula).font(.subheadline)
                }

                if let mnemonic = item.mnemonic {
                    highlighted(mnemonic)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                } else if item.components.isEmpty, item.formula == nil, let note = item.note {
                    Text(note)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// Tô đậm nghĩa các bộ phận và phần kết luận sau "→" (chỉ khớp nguyên từ).
    private func highlighted(_ text: String) -> Text {
        var attributed = AttributedString(text)
        let plain = text as NSString
        for word in item.mnemonicHighlights {
            var searchRange = NSRange(location: 0, length: plain.length)
            while true {
                let found = plain.range(of: word, options: [.caseInsensitive], range: searchRange)
                guard found.location != NSNotFound else { break }
                if isWholeWord(found, in: plain),
                   let range = Range(found, in: text),
                   let attributedRange = Range(range, in: attributed) {
                    attributed[attributedRange].font = .subheadline.bold()
                }
                let next = found.location + found.length
                searchRange = NSRange(location: next, length: plain.length - next)
            }
        }
        return Text(attributed)
    }

    private func isWholeWord(_ range: NSRange, in text: NSString) -> Bool {
        func isLetter(at index: Int) -> Bool {
            guard index >= 0, index < text.length else { return false }
            return CharacterSet.letters.contains(UnicodeScalar(text.character(at: index)) ?? " ")
        }
        return !isLetter(at: range.location - 1) && !isLetter(at: range.location + range.length)
    }

    private var accessibilityText: String {
        var parts = ["Chữ \(item.character)"]
        if let hanViet = item.hanViet { parts.append(hanViet) }
        if !item.components.isEmpty {
            parts.append(item.components.map { [$0.character, $0.hanViet, $0.meaning].compactMap { $0 }.joined(separator: " ") }
                .joined(separator: " cộng "))
        } else if let formula = item.formula {
            parts.append(formula)
        }
        if let mnemonic = item.mnemonic { parts.append(mnemonic) } else if let note = item.note { parts.append(note) }
        return parts.joined(separator: ", ")
    }
}

/// Thẻ một bộ phận: chữ trong ô tròn nhỏ, tên Hán Việt đậm, nghĩa xám.
struct ComponentChip: View {
    let component: DecompositionComponent

    var body: some View {
        HStack(spacing: 6) {
            Text(component.character)
                .font(.hanzi(15, weight: .regular))
                .frame(width: 24, height: 24)
                .background(Circle().fill(AppColor.fieldBackground))
                .overlay(Circle().strokeBorder(AppColor.cardBorder, lineWidth: 1))
            if let hanViet = component.hanViet {
                Text(hanViet).font(.footnote.weight(.semibold))
            }
            if let meaning = component.meaning {
                Text(meaning)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .frame(height: 32)
        .background(Capsule().fill(Color(hex: 0xF4F6F9)))
    }
}

private extension String {
    /// "nhĩ" → "Nhĩ".
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

/// Chiết tự gọn cho thẻ nền trắng (vd. Từ của ngày): chữ + âm Hán Việt, thẻ bộ phận, câu gợi nhớ.
struct CompactDecompositionView: View {
    let items: [CharacterDecomposition]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHIẾT TỰ")
                .font(.caption2.weight(.bold))
                .tracking(0.4)
                .foregroundStyle(AppColor.textSecondary)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Text(item.character).font(.hanzi(22))
                        if let hanViet = item.hanViet {
                            Text(hanViet)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColor.brand)
                        }
                    }
                    .frame(minWidth: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        if item.components.isEmpty {
                            Text(item.formula ?? item.note ?? "").font(.footnote)
                        } else {
                            FlowLayout(spacing: 4) {
                                ForEach(Array(item.components.enumerated()), id: \.offset) { offset, component in
                                    if offset > 0 {
                                        Text("+")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(AppColor.textTertiary)
                                            .frame(height: 32)
                                    }
                                    ComponentChip(component: component)
                                }
                            }
                        }
                        if let mnemonic = item.mnemonic {
                            Text(mnemonic)
                                .font(.footnote)
                                .foregroundStyle(AppColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
