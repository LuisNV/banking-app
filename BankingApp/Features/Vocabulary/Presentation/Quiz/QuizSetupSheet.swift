import Factory
import SwiftUI

extension QuizQuestionType {
    var title: String {
        switch self {
        case .hanziToMeaning: return "Hán → Nghĩa"
        case .meaningToHanzi: return "Nghĩa → Hán"
        case .audioToHanzi: return "Nghe → Hán"
        }
    }

    var subtitle: String {
        switch self {
        case .hanziToMeaning: return "Xem chữ Hán, chọn nghĩa"
        case .meaningToHanzi: return "Xem nghĩa, chọn chữ Hán"
        case .audioToHanzi: return "Nghe phát âm, chọn chữ Hán"
        }
    }

    var systemImage: String {
        switch self {
        case .hanziToMeaning: return "character.book.closed.fill"
        case .meaningToHanzi: return "textformat"
        case .audioToHanzi: return "speaker.wave.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .hanziToMeaning: return Color(.systemBlue)
        case .meaningToHanzi: return Color(.systemOrange)
        case .audioToHanzi: return Color(.systemPink)
        }
    }
}

/// Bottom sheet chọn phạm vi, số câu và dạng câu hỏi trước khi kiểm tra.
struct QuizSetupSheet: View {
    let level: Int
    let summary: VocabSummary
    let onStart: (QuizConfig) -> Void

    @State private var config: QuizConfig
    @State private var lastAttempt: QuizAttemptSummary?
    @Environment(\.dismiss) private var dismiss

    private let questionCounts = [10, 20, 30]

    init(level: Int, summary: VocabSummary, onStart: @escaping (QuizConfig) -> Void) {
        self.level = level
        self.summary = summary
        self.onStart = onStart
        _config = State(initialValue: QuizConfig(level: level))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                scopeSection
                countSection
                typeSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(startTitle) { onStart(config) }
                .buttonStyle(PrimaryButtonStyle(isPill: true))
                .disabled(!canStart)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .background(AppColor.background)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .task { lastAttempt = await Container.shared.vocabularyRepository().lastQuizAttempt(level: level) }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kiểm tra HSK \(level)").font(.title2.bold())
                if let lastAttempt {
                    Text("Lần trước: \(lastAttempt.correct)/\(lastAttempt.total) câu đúng · \(lastAttempt.finishedAt.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            Spacer(minLength: 12)
            CircleIconButton(
                systemImage: "xmark",
                accessibilityLabel: "Đóng",
                foreground: AppColor.textSecondary,
                size: 32,
                action: { dismiss() }
            )
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Phạm vi")
            HStack(spacing: 8) {
                scopeTile(.all, title: "Tất cả", subtitle: "\(summary.total) từ")
                scopeTile(.learning, title: "Đang học", subtitle: "\(summary.learning) từ", disabled: summary.learning == 0)
                scopeTile(.known, title: "Đã thuộc", subtitle: "\(summary.known) từ", disabled: summary.known == 0)
            }
        }
    }

    private func scopeTile(_ scope: QuizScope, title: String, subtitle: String, disabled: Bool = false) -> some View {
        Button {
            config.scope = scope
        } label: {
            ScopeTileLabel(title: title, subtitle: subtitle, isSelected: config.scope == scope)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .accessibilityAddTraits(config.scope == scope ? .isSelected : [])
    }

    private var countSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Số câu")
            HStack(spacing: 8) {
                ForEach(questionCounts, id: \.self) { count in
                    Button("\(count) câu") { config.questionCount = count }
                        .buttonStyle(SelectableChipStyle(isSelected: config.questionCount == count, height: 44, fillsWidth: true))
                        .accessibilityAddTraits(config.questionCount == count ? .isSelected : [])
                }
            }
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Dạng câu hỏi")
            GroupedCard {
                ForEach(Array(QuizQuestionType.allCases.enumerated()), id: \.element) { offset, type in
                    if offset > 0 { GroupedDivider(leadingInset: 56) }
                    let isOn = config.types.contains(type)
                    Button {
                        if isOn { config.types.remove(type) } else { config.types.insert(type) }
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(systemImage: type.systemImage, tint: type.tint)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(type.title).font(.subheadline.weight(.semibold))
                                Text(type.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                            Spacer()
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(isOn ? AppColor.brand : AppColor.fieldBorder)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }

    // MARK: Helpers

    private var canStart: Bool { !config.types.isEmpty }

    private var startTitle: String {
        canStart ? "Bắt đầu · \(config.questionCount) câu" : "Chọn ít nhất 1 dạng câu"
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppColor.fieldLabel)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ScopeTileLabel: View {
    let title: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? AppColor.brand : AppColor.textPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? AppColor.brandTint : AppColor.fieldBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? AppColor.brand : AppColor.cardBorder, lineWidth: isSelected ? 2 : 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
