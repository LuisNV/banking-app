import SwiftUI

/// Học thẻ ghi nhớ: xấp thẻ, chạm để lật (mặt sau màu thương hiệu), vuốt hoặc bấm Chưa nhớ / Đã nhớ.
struct FlashcardView: View {
    @State private var viewModel: FlashcardViewModel
    @State private var dragOffset: CGSize = .zero
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: FlashcardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if viewModel.isFinished {
                finished
            } else if let card = viewModel.currentCard {
                counters.padding(.top, 10)
                deck(card)
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                Text("Vuốt trái: chưa nhớ · Vuốt phải: đã nhớ")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.top, 34)
                Spacer(minLength: 12)
                actions
            } else if let message = viewModel.errorMessage {
                ContentUnavailableView("Không tải được thẻ", systemImage: "wifi.exclamationmark", description: Text(message))
            } else if viewModel.isEmpty {
                ContentUnavailableView(
                    "Chưa có thẻ cần học",
                    systemImage: "checkmark.seal",
                    description: Text(viewModel.emptyMessage)
                )
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .background(AppColor.background)
        .task { await viewModel.load() }
    }

    // MARK: Parts

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Đóng")
            ProgressView(value: viewModel.progress)
                .tint(AppColor.brand)
                .animation(.easeOut, value: viewModel.progress)
            Text(viewModel.cards.isEmpty ? "" : viewModel.positionText)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppColor.textSecondary)
                .frame(minWidth: 52, alignment: .trailing)
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
    }

    private var counters: some View {
        HStack(spacing: 16) {
            Text("Chưa nhớ \(viewModel.againCount)").foregroundStyle(Color(hex: 0xC93400))
            Text("Đã nhớ \(viewModel.goodCount)").foregroundStyle(Color(hex: 0x1E7A37))
        }
        .font(.footnote.weight(.semibold))
    }

    private func deck(_ card: Flashcard) -> some View {
        ZStack {
            // Các thẻ phía sau (tối đa 2) cho cảm giác xấp thẻ.
            ForEach((0..<min(viewModel.remainingBehind, 2)).reversed(), id: \.self) { depth in
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppColor.fieldBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(AppColor.cardBorder, lineWidth: 1.5)
                    }
                    .padding(.horizontal, CGFloat(depth + 1) * 12)
                    .offset(y: CGFloat(depth + 1) * 13)
            }

            FlashcardFace(card: card, isFlipped: viewModel.isFlipped)
                .id(card.id)
                .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width) / 25))
                .overlay(alignment: .top) { swipeHint }
                .onTapGesture { flip() }
                .gesture(swipe)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Chạm hai lần để lật thẻ")
                .accessibilityAction(named: "Đã nhớ") { answer(.good) }
                .accessibilityAction(named: "Chưa nhớ") { answer(.again) }
        }
        .frame(maxHeight: 460)
    }

    @ViewBuilder
    private var swipeHint: some View {
        let width = dragOffset.width
        if abs(width) > 30 {
            Text(width > 0 ? "ĐÃ NHỚ" : "CHƯA NHỚ")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(width > 0 ? AppColor.success : AppColor.danger)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .overlay(Capsule().strokeBorder(width > 0 ? AppColor.success : AppColor.danger, lineWidth: 2))
                .background(Capsule().fill(AppColor.fieldBackground))
                .opacity(min(Double(abs(width) - 30) / 60, 1))
                .padding(.top, 18)
                .accessibilityHidden(true)
        }
    }

    private var swipe: some Gesture {
        DragGesture()
            .onChanged { dragOffset = CGSize(width: $0.translation.width, height: $0.translation.height * 0.2) }
            .onEnded { value in
                let width = value.translation.width
                if width > 110 {
                    answer(.good)
                } else if width < -110 {
                    answer(.again)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = .zero }
                }
            }
    }

    private var actions: some View {
        HStack(spacing: 22) {
            Button { answer(.again) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: 0xC93400))
                    .frame(width: 68, height: 68)
                    .outlinedSurface(Circle(), borderColor: Color(hex: 0xF3C4B5))
            }
            .accessibilityLabel("Chưa nhớ")

            SpeakerButton(size: 52) { viewModel.play() }

            Button { answer(.good) } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(AppColor.success))
                    .shadow(color: AppColor.success.opacity(0.3), radius: 9, y: 4)
            }
            .accessibilityLabel("Đã nhớ")
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }

    private var finished: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.brand)
                .accessibilityHidden(true)
            Text("Xong lượt học!").font(.title.bold())
            Text("Đã nhớ \(viewModel.goodCount) · Chưa nhớ \(viewModel.againCount)")
                .foregroundStyle(AppColor.textSecondary)
            Text(viewModel.savesProgress
                 ? "Từ chưa nhớ sẽ được nhắc ôn lại sớm."
                 : "Kết quả lượt này chưa được lưu lên tài khoản.")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            VStack(spacing: 10) {
                Button("Xong") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle(isPill: true))
                if case .level = viewModel.source {
                    Button("Học tiếp lượt mới") { viewModel.restart() }
                        .buttonStyle(OutlinedPillButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private func flip() {
        if reduceMotion {
            viewModel.flip()
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { viewModel.flip() }
        }
    }

    private func answer(_ result: ReviewResult) {
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = .zero
            viewModel.answer(result)
        }
    }
}

/// Thẻ hai mặt: trước nền trắng chỉ có chữ Hán; sau nền xanh có pinyin, nghĩa, ví dụ.
private struct FlashcardFace: View {
    let card: Flashcard
    let isFlipped: Bool

    private var word: VocabWord { card.word }

    var body: some View {
        ZStack {
            front
                .opacity(isFlipped ? 0 : 1)
                .accessibilityHidden(isFlipped)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
                .accessibilityHidden(!isFlipped)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
    }

    private var front: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColor.fieldBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(AppColor.cardBorder, lineWidth: 1.5)
                }
                .shadow(color: .black.opacity(0.08), radius: 17, y: 10)
            VStack {
                HStack {
                    reasonChip
                    Spacer()
                }
                Spacer()
                Text(word.hanzi)
                    .font(.hanzi(96))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Spacer()
                Label("Chạm để lật thẻ", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textTertiary)
            }
            .padding(20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mặt trước: \(word.hanzi)\(card.reason == .due ? ", ôn tập" : card.reason == .new ? ", từ mới" : "")")
    }

    /// "Ôn tập" (cam) / "Từ mới" (xanh); thẻ ôn lại từ sai thì ghi cấp HSK.
    @ViewBuilder
    private var reasonChip: some View {
        switch card.reason {
        case .due:
            chip("Ôn tập", foreground: Color(hex: 0x9A3A00), background: Color(hex: 0xFFF1E3))
        case .new:
            chip("Từ mới", foreground: AppColor.brandDark, background: AppColor.brandTint)
        case nil:
            Text(word.topic ?? "HSK \(word.level)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .overlay(Capsule().strokeBorder(AppColor.fieldBorder, lineWidth: 1))
        }
    }

    private func chip(_ title: String, foreground: Color, background: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(background))
    }

    private var back: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColor.brand)
                .shadow(color: AppColor.brand.opacity(0.3), radius: 17, y: 10)
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                Text(word.hanzi).font(.hanzi(56))
                Text(word.pinyin)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                if let hanViet = word.hanViet {
                    Text("Hán Việt: \(hanViet)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                // Chiết tự gọn: "爱 = 爫 + 冖 + 友", tối đa 2 chữ cho vừa thẻ.
                ForEach(Array(word.decomposition.prefix(2).enumerated()), id: \.offset) { _, item in
                    Text("\(item.character) = \(item.compactFormula ?? "")")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(width: 48, height: 1.5)
                    .padding(.vertical, 12)
                Text(word.meaning)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                if let partOfSpeech = word.partOfSpeech {
                    Text(partOfSpeech)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                if let example = word.examples.first {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example.hanzi).font(.hanzi(18, weight: .regular))
                        Text(example.pinyin)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.75))
                        Text(example.meaning).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.14)))
                    .padding(.top, 18)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .accessibilityElement(children: .combine)
    }
}
