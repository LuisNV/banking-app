import SwiftUI

/// Bảng Pinyin: 3 tab Thanh mẫu / Vận mẫu / Ghép âm, khung chi tiết ở cuối màn.
struct PinyinChartView: View {
    @State private var viewModel = PinyinChartViewModel()

    private let soundColumns = [GridItem(.adaptive(minimum: 62), spacing: 8)]
    private let syllableColumns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
                .padding(.horizontal, 16)
                .padding(.top, 8)

            if viewModel.chart != nil {
                ScrollView {
                    Group {
                        if viewModel.tab == .combinations {
                            combinations
                        } else {
                            soundGroups
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { detailPanel }
            } else if let message = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Không tải được bảng Pinyin", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Thử lại") { Task { await viewModel.load() } }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .navigationTitle("Bảng Pinyin")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    // MARK: Tabs

    private var tabPicker: some View {
        HStack(spacing: 2) {
            ForEach(PinyinChartViewModel.Tab.allCases, id: \.self) { tab in
                let isSelected = viewModel.tab == tab
                Button {
                    withAnimation(.snappy) { viewModel.tab = tab }
                } label: {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : AppColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(Capsule().fill(isSelected ? AppColor.brand : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .outlinedSurface(Capsule())
    }

    // MARK: Thanh mẫu / Vận mẫu

    private var soundGroups: some View {
        let selected = viewModel.selectedSound?.symbol
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.groups) { group in
                Text(group.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: soundColumns, spacing: 8) {
                    ForEach(group.sounds) { sound in
                        SoundCell(sound: sound, isSelected: sound.symbol == selected) {
                            viewModel.select(sound)
                        }
                    }
                }
            }
        }
    }

    // MARK: Ghép âm

    private var combinations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chọn thanh mẫu · \(viewModel.totalCombinations) cách ghép")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .padding(.horizontal, 4)
                .padding(.top, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.combinationInitials, id: \.self) { initial in
                        Button(initial.isEmpty ? "Không có" : initial) {
                            withAnimation(.snappy) { viewModel.selectCombinationInitial(initial) }
                        }
                        .buttonStyle(SelectableChipStyle(isSelected: initial == viewModel.currentCombinationInitial, height: 36))
                        .accessibilityLabel(initial.isEmpty ? "Không có thanh mẫu" : "Thanh mẫu \(initial)")
                    }
                }
            }
            .scrollClipDisabled()

            LazyVGrid(columns: syllableColumns, spacing: 8) {
                ForEach(viewModel.combinationsForInitial) { combination in
                    let isSelected = combination == viewModel.currentCombination
                    Button {
                        viewModel.select(combination)
                    } label: {
                        VStack(spacing: 1) {
                            Text(combination.syllable)
                                .font(.headline)
                                .foregroundStyle(isSelected ? AppColor.brand : AppColor.textPrimary)
                            Text("+ \(combination.final)")
                                .font(.caption2)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isSelected ? AppColor.brandTint : AppColor.fieldBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(isSelected ? AppColor.brand : AppColor.cardBorder, lineWidth: isSelected ? 2 : 1.5)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(combination.initial) cộng \(combination.final) thành \(combination.syllable)")
                }
            }
        }
    }

    // MARK: Khung chi tiết

    @ViewBuilder
    private var detailPanel: some View {
        if viewModel.tab == .combinations {
            if let combination = viewModel.currentCombination {
                panel {
                    Text(combination.syllable)
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.brand)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 56, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColor.brandTint))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(combination.initial.isEmpty
                             ? "\(combination.final) → \(combination.syllable)"
                             : "\(combination.initial) + \(combination.final) → \(combination.syllable)")
                            .font(.subheadline.weight(.semibold))
                        Text(combinationNote(combination))
                            .font(.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else if let sound = viewModel.selectedSound {
            panel {
                Text(sound.symbol)
                    .font(.title.bold())
                    .foregroundStyle(AppColor.brand)
                    .padding(.horizontal, 8)
                    .frame(minWidth: 56, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColor.brandTint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(exampleLine(sound))
                        .font(.subheadline.weight(.semibold))
                    if let tip = sound.tip {
                        Text(tip)
                            .font(.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if sound.audioURL != nil || sound.exampleHanzi != nil {
                    SpeakerButton(size: 44, filled: true, accessibilityLabel: "Nghe \(sound.examplePinyin ?? sound.symbol)") {
                        viewModel.play(sound)
                    }
                }
            }
        }
    }

    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) { content() }
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(AppColor.fieldBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(AppColor.cardBorder, lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .accessibilityElement(children: .contain)
    }

    /// "zhōng 中 · giữa"
    private func exampleLine(_ sound: PinyinSound) -> String {
        [
            [sound.examplePinyin, sound.exampleHanzi].compactMap { $0 }.joined(separator: " "),
            sound.meaning ?? "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    private func combinationNote(_ combination: PinyinCombination) -> String {
        if combination.initial.isEmpty {
            return "Âm tiết không có thanh mẫu."
        }
        let expected = combination.initial + combination.final
        if expected != combination.syllable {
            // Quy tắc viết khác cách ghép thẳng (vd. j + ü → ju, bỏ hai chấm).
            return "Viết là “\(combination.syllable)” chứ không phải “\(expected)”."
        }
        return viewModel.initialSound(combination.initial)?.tip ?? "Ghép thẳng thanh mẫu và vận mẫu."
    }
}

/// Ô một âm: ký hiệu lớn + chữ ví dụ nhỏ.
private struct SoundCell: View {
    let sound: PinyinSound
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(sound.symbol)
                    .font(.title3.bold())
                    .foregroundStyle(isSelected ? AppColor.brand : AppColor.textPrimary)
                Text([sound.examplePinyin, sound.exampleHanzi].compactMap { $0 }.joined(separator: " "))
                    .font(.caption2)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(isSelected ? AppColor.brandTint : AppColor.fieldBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? AppColor.brand : AppColor.cardBorder, lineWidth: isSelected ? 2 : 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sound.symbol), ví dụ \(sound.examplePinyin ?? "") \(sound.meaning ?? "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
