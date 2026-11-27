import SwiftUI

/// Thanh điệu: 4 thẻ thanh (đường cao độ), khối luyện nghe 10 câu, mẹo biến điệu.
struct TonesView: View {
    @State private var viewModel = TonesViewModel()

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                toneCards
                practiceCard
                if let tip = viewModel.guide?.sandhiTip {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Color(.systemOrange))
                            .accessibilityHidden(true)
                        (Text("Biến điệu: ").fontWeight(.semibold) + Text(tip))
                            .font(.footnote)
                            .foregroundStyle(Color(hex: 0x6B4A1F))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0xFFF6EB)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Thanh điệu")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    // MARK: Thẻ thanh

    @ViewBuilder
    private var toneCards: some View {
        if let guide = viewModel.guide {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(guide.tones) { tone in
                    Button { viewModel.playTone(tone) } label: { ToneCard(tone: tone) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Thanh \(tone.number), \(tone.pinyin). \(tone.description)")
                        .accessibilityHint("Chạm để nghe")
                }
            }
        } else if let error = viewModel.guideError {
            retryBox(error) { Task { await viewModel.loadGuide() } }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    // MARK: Luyện nghe

    private var practiceCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Luyện nghe").font(.headline)
                Spacer()
                if !viewModel.questions.isEmpty && !viewModel.isFinished {
                    Text(viewModel.roundText)
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            if viewModel.isFinished {
                finished
            } else if let question = viewModel.question {
                questionView(question)
            } else if let error = viewModel.practiceError {
                retryBox(error) { Task { await viewModel.loadPractice() } }
            } else {
                ProgressView().frame(minHeight: 160)
            }
        }
        .padding(16)
        .outlinedSurface(cornerRadius: 22)
    }

    private func questionView(_ question: TonePracticeQuestion) -> some View {
        VStack(spacing: 12) {
            Button { viewModel.playQuestion() } label: {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(AppColor.brand))
                    .shadow(color: AppColor.brand.opacity(0.25), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nghe lại \(question.hanzi)")

            promptText(question)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ForEach(viewModel.guide?.tones ?? Self.fallbackTones) { tone in
                    ToneChoiceButton(
                        tone: tone,
                        state: choiceState(tone.number, question: question)
                    ) { viewModel.pick(tone.number) }
                }
            }

            Text(feedbackText(question))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(feedbackColor)
                .frame(minHeight: 20)

            Button("Câu tiếp") { viewModel.next() }
                .buttonStyle(PrimaryButtonStyle(isPill: true))
                .disabled(!viewModel.isAnswered)
        }
        .onAppear { if viewModel.index == 0 && !viewModel.isAnswered { viewModel.playQuestion() } }
    }

    /// "你好 · nghe âm thứ 2 “hao” (好): thanh mấy?"
    private func promptText(_ question: TonePracticeQuestion) -> Text {
        var text = Text(question.hanzi).font(.hanzi(17, weight: .regular)).foregroundColor(AppColor.textPrimary)
        if question.hanzi.count > 1 {
            text = text + Text(" · âm thứ \(question.syllablePosition) ")
        } else {
            text = text + Text(" · âm ")
        }
        text = text + Text("“\(question.syllable)”").fontWeight(.semibold).foregroundColor(AppColor.textPrimary)
        if question.hanzi.count > 1, let character = question.targetCharacter {
            text = text + Text(" (\(character))")
        }
        return text + Text(" mang thanh mấy?")
    }

    private var finished: some View {
        VStack(spacing: 10) {
            Text("\(viewModel.score)/\(viewModel.questions.count)")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(viewModel.score * 10 >= viewModel.questions.count * 8 ? AppColor.success : AppColor.textPrimary)
            Text(viewModel.score == viewModel.questions.count ? "Tuyệt vời, đúng hết!" : "Nghe thêm vài lượt nữa nhé.")
                .foregroundStyle(AppColor.textSecondary)
            Button("Luyện lượt mới") { Task { await viewModel.loadPractice() } }
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoadingPractice, isPill: true))
                .disabled(viewModel.isLoadingPractice)
        }
        .padding(.vertical, 8)
    }

    private func choiceState(_ tone: Int, question: TonePracticeQuestion) -> ToneChoiceButton.Appearance {
        guard let picked = viewModel.pickedTone else { return .idle }
        if tone == question.correctTone { return .correct }
        if tone == picked { return .wrong }
        return .dimmed
    }

    private func feedbackText(_ question: TonePracticeQuestion) -> String {
        guard viewModel.isAnswered else { return "Chạm vào thanh bạn nghe được" }
        return viewModel.isCorrect ? "✓ Chính xác!" : "✕ Chưa đúng · Đó là thanh \(question.correctTone)"
    }

    private var feedbackColor: Color {
        guard viewModel.isAnswered else { return AppColor.textTertiary }
        return viewModel.isCorrect ? Color(hex: 0x1E7A37) : Color(hex: 0xC4271C)
    }

    private func retryBox(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("Thử lại", action: retry)
                .buttonStyle(SelectableChipStyle(isSelected: false, height: 40))
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    /// Khi chưa tải được hướng dẫn vẫn luyện được: đường cao độ chuẩn.
    private static let fallbackTones = [
        ToneInfo(number: 1, pinyin: "", pitch: [5, 5], description: ""),
        ToneInfo(number: 2, pinyin: "", pitch: [3, 5], description: ""),
        ToneInfo(number: 3, pinyin: "", pitch: [2, 1, 4], description: ""),
        ToneInfo(number: 4, pinyin: "", pitch: [5, 1], description: ""),
    ]
}

extension ToneInfo {
    /// Màu riêng mỗi thanh: 1 xanh dương, 2 xanh lá, 3 cam, 4 đỏ.
    var color: Color {
        switch number {
        case 1: return Color(hex: 0x0A5BD3)
        case 2: return Color(hex: 0x1E9E55)
        case 3: return Color(hex: 0xD97706)
        default: return Color(hex: 0xD92D20)
        }
    }
}

/// Đường cao độ: nối các mức `pitch` (1 thấp → 5 cao) từ trái sang phải; 3 điểm thì vẽ cong qua điểm giữa.
struct PitchContour: Shape {
    let pitch: [Int]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !pitch.isEmpty else { return path }
        let values = pitch.count == 1 ? [pitch[0], pitch[0]] : pitch
        let points = values.enumerated().map { index, value in
            CGPoint(
                x: rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1),
                y: rect.minY + rect.height * CGFloat(5 - value) / 4
            )
        }
        path.move(to: points[0])
        if points.count == 3 {
            // Điểm điều khiển để đường cong đi qua đúng điểm giữa.
            let control = CGPoint(
                x: 2 * points[1].x - (points[0].x + points[2].x) / 2,
                y: 2 * points[1].y - (points[0].y + points[2].y) / 2
            )
            path.addQuadCurve(to: points[2], control: control)
        } else {
            for point in points.dropFirst() { path.addLine(to: point) }
        }
        return path
    }
}

/// Khung 5 mức cao độ với đường thanh điệu.
struct PitchChart: View {
    let pitch: [Int]
    let color: Color
    var lineWidth: CGFloat = 3.5
    var showsGrid = true

    var body: some View {
        ZStack {
            if showsGrid {
                VStack(spacing: 0) {
                    ForEach(0..<5) { index in
                        Rectangle().fill(AppColor.rowDivider).frame(height: 1)
                        if index < 4 { Spacer(minLength: 0) }
                    }
                }
            }
            PitchContour(pitch: pitch)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .padding(.horizontal, lineWidth)
        }
        .accessibilityHidden(true)
    }
}

private struct ToneCard: View {
    let tone: ToneInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Thanh \(tone.number)")
                    .font(.footnote.weight(.bold))
                Spacer()
                Text(tone.pinyin)
                    .font(.title3.bold())
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .opacity(tone.audioURL == nil ? 0 : 0.7)
            }
            .foregroundStyle(tone.color)
            PitchChart(pitch: tone.pitch, color: tone.color)
                .frame(height: 34)
            Text(tone.description)
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .outlinedSurface(cornerRadius: 18)
        .contentShape(Rectangle())
    }
}

private struct ToneChoiceButton: View {
    enum Appearance { case idle, correct, wrong, dimmed }

    let tone: ToneInfo
    let state: Appearance
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                PitchChart(pitch: tone.pitch, color: foreground, lineWidth: 4, showsGrid: false)
                    .frame(width: 40, height: 24)
                Text("\(tone.number)").font(.headline)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(background))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(border, lineWidth: state == .correct || state == .wrong ? 2 : 1.5)
            }
            .opacity(state == .dimmed ? 0.5 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .accessibilityLabel("Thanh \(tone.number)")
        .accessibilityValue(state == .correct ? "Đáp án đúng" : state == .wrong ? "Bạn chọn, sai" : "")
    }

    private var foreground: Color {
        switch state {
        case .correct: return Color(hex: 0x1E7A37)
        case .wrong: return Color(hex: 0xC4271C)
        case .idle, .dimmed: return tone.color
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
}
