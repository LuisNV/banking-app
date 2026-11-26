import SwiftUI

/// Chi tiết một từ: chữ Hán, pinyin, nghĩa, Hán Việt, ví dụ; bấm trước/sau và đánh dấu đã thuộc.
struct VocabularyDetailView: View {
    @State private var viewModel: VocabularyDetailViewModel

    init(viewModel: VocabularyDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                detailSections
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .id(viewModel.word.id)
            .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.word.id)
        .task(id: viewModel.word.id) { await viewModel.loadDetailIfNeeded() }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.positionText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .monospacedDigit()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                if value.translation.width < -60 { viewModel.next() }
                if value.translation.width > 60 { viewModel.previous() }
            }
        )
        .errorPopup("Không thể cập nhật", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        ), message: viewModel.errorMessage)
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 0) {
            VocabStatusBadge(status: viewModel.entry.status)
            Text(viewModel.word.hanzi)
                .font(.hanzi(76))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.top, 12)
            HStack(spacing: 10) {
                Text(viewModel.word.pinyin)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(AppColor.brand)
                SpeakerButton(size: 44, filled: true, accessibilityLabel: "Nghe phát âm \(viewModel.word.pinyin)") {
                    viewModel.play()
                }
            }
            .padding(.top, 2)
            Text(viewModel.word.meaning)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            if let partOfSpeech = viewModel.word.partOfSpeech {
                Text(partOfSpeech)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Phần chỉ có sau khi tải chi tiết: Hán Việt, cách dùng, ví dụ.
    @ViewBuilder
    private var detailSections: some View {
        let word = viewModel.word
        if !word.hasDetail {
            if let error = viewModel.detailError {
                VStack(spacing: 10) {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Thử lại") { Task { await viewModel.loadDetailIfNeeded() } }
                        .buttonStyle(SelectableChipStyle(isSelected: false, height: 40))
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        } else {
            if word.hanViet != nil { hanVietSection }
            if let usageNote = word.usageNote { usageSection(usageNote) }
            if !word.examples.isEmpty { examplesSection }
        }
    }

    private var hanVietSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Hán Việt")
            VStack(alignment: .leading, spacing: 10) {
                Text((viewModel.word.hanViet ?? "").uppercased())
                    .font(.headline)
                    .tracking(0.4)
                    .foregroundStyle(AppColor.brand)
                if let note = viewModel.word.hanVietNote {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !viewModel.word.characters.isEmpty {
                    FlowLayout(spacing: 18) {
                        ForEach(viewModel.word.characters, id: \.self) { character in
                            HStack(spacing: 8) {
                                Text(character.hanzi).font(.hanzi(20, weight: .regular))
                                Text(character.reading).font(.subheadline.weight(.semibold))
                                Text(character.meaning)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .outlinedSurface(cornerRadius: 22)
        }
    }

    private func usageSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Cách dùng")
            Text(note)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .outlinedSurface(cornerRadius: 22)
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Ví dụ")
            GroupedCard {
                ForEach(Array(viewModel.word.examples.enumerated()), id: \.offset) { offset, example in
                    if offset > 0 { GroupedDivider(leadingInset: 14) }
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            highlighted(example.hanzi)
                                .font(.hanzi(20, weight: .regular))
                            if !example.pinyin.isEmpty {
                                Text(example.pinyin)
                                    .font(.footnote)
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                            if !example.meaning.isEmpty {
                                Text(example.meaning).font(.subheadline)
                            }
                            if let note = example.note {
                                Text(note)
                                    .font(.footnote)
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        SpeakerButton(size: 36, accessibilityLabel: "Nghe câu ví dụ \(offset + 1)") {
                            viewModel.play(example)
                        }
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 10)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private var bottomBar: some View {
        let isKnown = viewModel.entry.status == .known
        return HStack(spacing: 10) {
            navButton(systemImage: "chevron.left", label: "Từ trước", enabled: viewModel.canGoPrevious) {
                viewModel.previous()
            }
            if viewModel.canUpdateProgress {
                Button {
                    Task { await viewModel.toggleKnown() }
                } label: {
                    Label(isKnown ? "Học lại từ này" : "Đánh dấu đã thuộc",
                          systemImage: isKnown ? "arrow.counterclockwise" : "checkmark")
                }
                .buttonStyle(isKnown ? AnyButtonStyle(OutlinedPillButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle(isLoading: viewModel.isUpdating, isPill: true)))
                .disabled(viewModel.isUpdating)
            } else {
                // Chưa có API ghi tiến độ: chỉ còn nút trước/sau, đẩy ra hai bên.
                Spacer()
            }
            navButton(systemImage: "chevron.right", label: "Từ tiếp theo", enabled: viewModel.canGoNext) {
                viewModel.next()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(AppColor.background)
    }

    // MARK: Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppColor.textSecondary)
            .padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func navButton(systemImage: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? AppColor.textPrimary : AppColor.textTertiary)
                .frame(width: 52, height: 52)
                .outlinedSurface(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// Tô xanh từ đang học trong câu ví dụ.
    private func highlighted(_ sentence: String) -> Text {
        let target = viewModel.word.hanzi
        var attributed = AttributedString(sentence)
        if let range = attributed.range(of: target) {
            attributed[range].foregroundColor = AppColor.brand
            attributed[range].font = .hanzi(20, weight: .bold)
        }
        return Text(attributed)
    }
}

/// Nút viên thuốc viền mảnh, chữ xanh (nút phụ ngang hàng nút chính).
struct OutlinedPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppColor.brand)
            .frame(maxWidth: .infinity)
            .frame(height: AppMetrics.pillButtonHeight)
            .outlinedSurface(Capsule(), borderColor: AppColor.fieldBorder)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

/// Bọc ButtonStyle để chọn kiểu theo điều kiện.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}
