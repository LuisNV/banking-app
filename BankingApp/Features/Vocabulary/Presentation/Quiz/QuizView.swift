import SwiftUI

/// Làm bài kiểm tra trắc nghiệm 4 đáp án và xem kết quả.
struct QuizView: View {
    @State private var viewModel: QuizViewModel
    @State private var isConfirmingExit = false
    @Environment(\.dismiss) private var dismiss

    let onReviewWrongWords: ([VocabWord]) -> Void
    let onNewQuiz: () -> Void

    init(
        viewModel: QuizViewModel,
        onReviewWrongWords: @escaping ([VocabWord]) -> Void,
        onNewQuiz: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onReviewWrongWords = onReviewWrongWords
        self.onNewQuiz = onNewQuiz
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .loading, .submitting:
                    ProgressView(viewModel.phase == .submitting ? "Đang chấm bài…" : "Đang tạo đề…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let message):
                    failed(message)
                case .question:
                    if let question = viewModel.question {
                        QuizQuestionScreen(viewModel: viewModel, question: question) { isConfirmingExit = true }
                    }
                case .result(let submission):
                    QuizResultScreen(
                        viewModel: viewModel,
                        submission: submission,
                        onClose: { dismiss() },
                        onReviewWrongWords: { words in
                            onReviewWrongWords(words)
                            dismiss()
                        },
                        onNewQuiz: {
                            onNewQuiz()
                            dismiss()
                        }
                    )
                }
            }
            .background(AppColor.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: VocabularyRoute.self) { route in
                if case .detail(let entries, let index) = route {
                    VocabularyDetailView(viewModel: VocabularyDetailViewModel(entries: entries, index: index))
                }
            }
        }
        .task { await viewModel.start() }
        .appPopup(isPresented: $isConfirmingExit) {
            AppPopup(
                style: .confirm,
                title: "Thoát bài kiểm tra?",
                message: "Bài đang làm dở sẽ không được lưu.",
                primary: .init(title: "Thoát", isDestructive: true) { dismiss() },
                secondary: .init(title: "Làm tiếp")
            )
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView("Không tạo được bài kiểm tra", systemImage: "exclamationmark.circle", description: Text(message))
            HStack(spacing: 10) {
                Button("Đóng") { dismiss() }
                    .buttonStyle(OutlinedPillButtonStyle())
                Button("Thử lại") { Task { await viewModel.retryStart() } }
                    .buttonStyle(PrimaryButtonStyle(isPill: true))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Câu hỏi

private struct QuizQuestionScreen: View {
    let viewModel: QuizViewModel
    let question: QuizQuestion
    let onExit: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 0) {
                    Text(question.type.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.fieldLabel)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .overlay(Capsule().strokeBorder(AppColor.fieldBorder, lineWidth: 1))
                        .padding(.top, 18)
                    Text(askText)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.top, 14)
                    prompt
                        .frame(height: 150)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(question.options) { option in
                            QuizOptionButton(
                                option: option,
                                isHanzi: question.optionsAreHanzi,
                                state: state(of: option)
                            ) {
                                withAnimation(.easeOut(duration: 0.2)) { viewModel.select(option) }
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            bottom
        }
        .id(question.id)
        .transition(.opacity)
        .animation(.easeOut(duration: 0.2), value: viewModel.isAnswered)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Thoát bài kiểm tra")
            ProgressView(value: viewModel.progress)
                .tint(AppColor.brand)
                .animation(.easeOut, value: viewModel.progress)
            Text("\(viewModel.number)/\(viewModel.total)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppColor.textSecondary)
                .frame(minWidth: 48, alignment: .trailing)
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
    }

    private var askText: String {
        switch question.type {
        case .hanziToMeaning: return "Từ này nghĩa là gì?"
        case .meaningToHanzi: return "Chọn chữ Hán đúng"
        case .audioToHanzi: return "Nghe và chọn chữ Hán"
        }
    }

    /// Đề bài. Chữ Hán ở đề không kèm pinyin (kể cả khi cài đặt luôn hiện pinyin).
    @ViewBuilder
    private var prompt: some View {
        switch question.type {
        case .hanziToMeaning:
            Text(question.word.hanzi)
                .font(.hanzi(72))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel("Chữ \(question.word.hanzi)")
        case .meaningToHanzi:
            Text("“\(question.word.meaning)”")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
        case .audioToHanzi:
            HStack(spacing: 14) {
                Button { viewModel.playWord() } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(Circle().fill(AppColor.brand))
                        .shadow(color: AppColor.brand.opacity(0.3), radius: 12, y: 5)
                }
                .accessibilityLabel("Phát lại")
                Button { viewModel.playWord(slow: true) } label: {
                    Text("0.5×")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppColor.brand)
                        .frame(width: 52, height: 52)
                        .outlinedSurface(Circle())
                }
                .accessibilityLabel("Nghe chậm")
            }
            .buttonStyle(.plain)
        }
    }

    private func state(of option: QuizOption) -> QuizOptionButton.Appearance {
        guard let selected = viewModel.selectedOptionID else { return .idle }
        if option.id == question.correctOptionID { return .correct }
        if option.id == selected { return .wrong }
        return .dimmed
    }

    @ViewBuilder
    private var bottom: some View {
        if viewModel.isAnswered {
            QuizFeedbackPanel(
                isCorrect: viewModel.isCorrect,
                word: question.word,
                nextTitle: viewModel.isLastQuestion ? "Xem kết quả" : "Tiếp tục",
                onPlay: { viewModel.play(question.word) },
                onNext: { Task { await viewModel.next() } }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            VStack(spacing: 12) {
                Text("Chạm vào một đáp án")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textTertiary)
                Button("Tiếp tục") {}
                    .buttonStyle(PrimaryButtonStyle(isPill: true))
                    .disabled(true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

private struct QuizOptionButton: View {
    enum Appearance { case idle, correct, wrong, dimmed }

    let option: QuizOption
    let isHanzi: Bool
    let state: Appearance
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(option.text)
                .font(isHanzi ? .hanzi(30) : .headline)
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 84)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(background))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(border, lineWidth: state == .idle || state == .dimmed ? 1.5 : 2)
                }
                .overlay(alignment: .topTrailing) { mark }
                .opacity(state == .dimmed ? 0.5 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .accessibilityLabel(option.text)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var mark: some View {
        if state == .correct || state == .wrong {
            Image(systemName: state == .correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, state == .correct ? AppColor.success : AppColor.danger)
                .padding(8)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var background: Color {
        switch state {
        case .correct: return Color(hex: 0xE9F8EE)
        case .wrong: return Color(hex: 0xFDECEC)
        case .idle, .dimmed: return AppColor.fieldBackground
        }
    }

    private var border: Color {
        switch state {
        case .correct: return AppColor.success
        case .wrong: return AppColor.danger
        case .idle, .dimmed: return AppColor.cardBorder
        }
    }

    private var textColor: Color {
        switch state {
        case .correct: return Color(hex: 0x1E7A37)
        case .wrong: return Color(hex: 0xC4271C)
        case .idle, .dimmed: return AppColor.textPrimary
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .correct: return "Đáp án đúng"
        case .wrong: return "Bạn chọn, sai"
        case .idle, .dimmed: return ""
        }
    }
}

/// Khung đúng/sai trượt lên sau khi chọn: đáp án đúng kèm pinyin, nghĩa, nút nghe.
private struct QuizFeedbackPanel: View {
    let isCorrect: Bool
    let word: VocabWord
    let nextTitle: String
    let onPlay: () -> Void
    let onNext: () -> Void

    private var tint: Color { isCorrect ? AppColor.success : AppColor.danger }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(tint)
                Text(isCorrect ? "Chính xác!" : "Chưa đúng · Đáp án là:")
                    .font(.title3.bold())
                    .foregroundStyle(isCorrect ? Color(hex: 0x1E7A37) : Color(hex: 0xC4271C))
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                Text(word.hanzi).font(.hanzi(26))
                VStack(alignment: .leading, spacing: 0) {
                    Text(word.pinyin)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.brand)
                    Text(word.meaning).font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SpeakerButton(action: onPlay)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColor.fieldBackground))

            Button(action: onNext) {
                Text(nextTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: AppMetrics.pillButtonHeight)
                    .background(Capsule().fill(tint))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(isCorrect ? Color(hex: 0xE9F8EE) : Color(hex: 0xFDECEC))
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Kết quả

private struct QuizResultScreen: View {
    let viewModel: QuizViewModel
    let submission: QuizSubmission
    let onClose: () -> Void
    let onReviewWrongWords: ([VocabWord]) -> Void
    let onNewQuiz: () -> Void

    private var percent: Int { submission.total == 0 ? 0 : submission.correct * 100 / submission.total }

    var body: some View {
        let wrong = viewModel.wrongAnswers
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Đóng")
                Spacer()
            }
            .padding(.leading, 4)

            ScrollView {
                VStack(spacing: 0) {
                    scoreRing
                    Text(headline)
                        .font(.title.bold())
                        .padding(.top, 16)
                    Text(subtitle(wrongCount: wrong.count))
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .padding(.horizontal, 12)

                    HStack(spacing: 8) {
                        stat("\(submission.correct)", "Đúng", color: Color(hex: 0x1E7A37))
                        stat("\(submission.total - submission.correct)", "Sai", color: Color(hex: 0xC4271C))
                        stat(durationText, "Thời gian", color: AppColor.textPrimary)
                    }
                    .padding(.top, 20)

                    if !wrong.isEmpty {
                        wrongList(wrong)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                if wrong.isEmpty {
                    Button("Xong", action: onClose)
                        .buttonStyle(PrimaryButtonStyle(isPill: true))
                } else {
                    Button {
                        onReviewWrongWords(wrong.map(\.word).uniqued())
                    } label: {
                        Label("Ôn lại \(Set(wrong.map(\.word.id)).count) từ sai", systemImage: "rectangle.on.rectangle")
                    }
                    .buttonStyle(PrimaryButtonStyle(isPill: true))
                }
                Button("Làm bài mới", action: onNewQuiz)
                    .buttonStyle(OutlinedPillButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var scoreRing: some View {
        ZStack {
            Circle().stroke(AppColor.rowDivider, lineWidth: 12)
            Circle()
                .trim(from: 0, to: Double(percent) / 100)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                (Text("\(submission.correct)").font(.system(size: 40, weight: .bold))
                 + Text("/\(submission.total)").font(.system(size: 22, weight: .bold)).foregroundStyle(AppColor.textTertiary))
                Text("\(percent)%")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: 148, height: 148)
        .padding(.top, 4)
        .accessibilityElement()
        .accessibilityLabel("Đúng \(submission.correct) trên \(submission.total) câu, \(percent) phần trăm")
    }

    private var ringColor: Color {
        percent >= 80 ? AppColor.success : (percent >= 50 ? Color(.systemOrange) : AppColor.danger)
    }

    private var headline: String {
        switch percent {
        case 100: return "Xuất sắc!"
        case 80...: return "Làm tốt lắm!"
        case 50...: return "Khá ổn!"
        default: return "Cố gắng thêm nhé!"
        }
    }

    private func subtitle(wrongCount: Int) -> String {
        var parts: [String] = []
        if let previous = submission.previousPercent {
            let diff = percent - previous
            if diff > 0 { parts.append("Cao hơn lần trước \(diff)%.") }
            else if diff < 0 { parts.append("Thấp hơn lần trước \(-diff)%.") }
            else { parts.append("Bằng lần trước.") }
        }
        if wrongCount > 0 {
            parts.append("Ôn lại \(wrongCount) câu sai để nhớ chắc hơn nhé.")
        } else {
            parts.append("Bạn trả lời đúng tất cả các câu.")
        }
        return parts.joined(separator: " ")
    }

    private var durationText: String {
        let seconds = Int(viewModel.duration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func stat(_ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(color)
            Text(label).font(.footnote).foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .outlinedSurface(cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }

    private func wrongList(_ wrong: [QuizViewModel.WrongAnswer]) -> some View {
        let entries = wrong.map(\.word).uniqued().map { word in
            // Trạng thái thật được nạp lại khi mở chi tiết (nếu bản API chưa trả trạng thái mới).
            VocabEntry(word: word, status: submission.statuses[word.id] ?? .learning)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text("TỪ LÀM SAI")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            GroupedCard {
                ForEach(Array(wrong.enumerated()), id: \.element.id) { offset, item in
                    if offset > 0 { GroupedDivider(leadingInset: 14) }
                    NavigationLink(value: VocabularyRoute.detail(
                        entries: entries,
                        index: entries.firstIndex { $0.word.id == item.word.id } ?? 0
                    )) {
                        HStack(spacing: 12) {
                            Text(item.word.hanzi)
                                .font(.hanzi(26))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(width: 72, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(item.word.pinyin) · \(item.word.meaning)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppColor.brand)
                                Text("Bạn chọn: \(item.chosenText)\(item.type == .audioToHanzi ? " (nghe)" : "")")
                                    .font(.footnote)
                                    .foregroundStyle(Color(hex: 0xC4271C))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppColor.textTertiary)
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 64)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if !submission.statuses.isEmpty {
                Text("Các từ làm sai đã chuyển về “Đang học” để được nhắc ôn sớm.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.top, 20)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
