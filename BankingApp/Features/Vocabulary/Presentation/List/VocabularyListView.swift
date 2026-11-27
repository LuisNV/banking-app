import SwiftUI

enum VocabularyRoute: Hashable {
    /// `entries`: danh sách đang hiện, để màn chi tiết bấm trước/sau.
    case detail(entries: [VocabEntry], index: Int)
}

/// Nguồn thẻ cho một lượt học thẻ ghi nhớ.
enum FlashcardSource: Hashable, Identifiable {
    case level(Int)
    /// Ôn lại đúng các từ này (từ làm sai trong bài kiểm tra).
    case words([VocabWord])

    var id: String {
        switch self {
        case .level(let level): return "level-\(level)"
        case .words(let words): return "words-" + words.map(\.id).joined(separator: ",")
        }
    }
}

struct QuizLaunch: Identifiable {
    let id = UUID()
    let config: QuizConfig
}

/// Màn "Từ vựng HSK": chọn cấp, tiến độ, học thẻ / kiểm tra, danh sách từ (tải dần khi cuộn).
struct VocabularyListView: View {
    @State private var viewModel = VocabularyListViewModel()
    @State private var flashcardSource: FlashcardSource?
    @State private var isShowingQuizSetup = false
    @State private var pendingQuiz: QuizConfig?
    @State private var quizLaunch: QuizLaunch?
    @State private var afterQuiz: AfterQuiz?

    private enum AfterQuiz {
        case review([VocabWord])
        case newQuiz
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.isEmptyState {
                    placeholder
                } else {
                    levelPicker
                    progressCard
                    filters
                    wordList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Từ vựng HSK")
        .navigationBarTitleDisplayMode(.inline)
        // Đích `VocabularyRoute` khai báo ở gốc NavigationStack của Trang chủ.
        .task { await viewModel.load() }
        .onAppear { refresh() }
        .sheet(isPresented: $isShowingQuizSetup, onDismiss: startPendingQuiz) {
            QuizSetupSheet(level: viewModel.selectedLevel, summary: viewModel.summary) { config in
                pendingQuiz = config
                isShowingQuizSetup = false
            }
        }
        .fullScreenCover(item: $flashcardSource, onDismiss: refresh) { source in
            FlashcardView(viewModel: FlashcardViewModel(source: source))
        }
        .fullScreenCover(item: $quizLaunch, onDismiss: handleAfterQuiz) { launch in
            QuizView(
                viewModel: QuizViewModel(config: launch.config),
                onReviewWrongWords: { words in afterQuiz = .review(words) },
                onNewQuiz: { afterQuiz = .newQuiz }
            )
        }
    }

    // MARK: Sections

    private var levelPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.levels) { level in
                    let isSelected = level.level == viewModel.selectedLevel
                    Button {
                        if level.isAvailable {
                            Task { await viewModel.select(level: level.level) }
                        } else {
                            AppPopupCenter.shared.showToast(AppToast(
                                title: "HSK \(level.level) sắp có",
                                message: "Từ vựng cấp này đang được cập nhật."
                            ))
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("HSK \(level.level)")
                            if !level.isAvailable {
                                Image(systemName: "lock.fill").font(.system(size: 11))
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : (level.isAvailable ? AppColor.textPrimary : AppColor.textTertiary))
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Capsule().fill(isSelected ? AppColor.brand : AppColor.fieldBackground))
                        .overlay {
                            if !isSelected { Capsule().strokeBorder(AppColor.cardBorder, lineWidth: 1.5) }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(level.isAvailable ? "HSK \(level.level)" : "HSK \(level.level), sắp có")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    private var progressCard: some View {
        let summary = viewModel.summary
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.levelTitle).font(.title3.bold())
                Spacer()
                (Text("\(summary.started)").fontWeight(.bold).foregroundStyle(AppColor.textPrimary)
                 + Text("/\(summary.total) từ"))
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }

            VocabProgressBar(summary: summary)

            HStack(spacing: 14) {
                legend(.known, count: summary.known)
                legend(.learning, count: summary.learning)
                legend(.notStarted, count: summary.notStarted)
            }
            .font(.footnote)
            .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: 10) {
                Button {
                    flashcardSource = .level(viewModel.selectedLevel)
                } label: {
                    Label("Học thẻ ghi nhớ", systemImage: "rectangle.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Capsule().fill(AppColor.brand))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    isShowingQuizSetup = true
                } label: {
                    Label("Kiểm tra", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(AppColor.brand)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .outlinedSurface(Capsule(), borderColor: AppColor.fieldBorder)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .disabled(summary.total == 0)
            .padding(.top, 2)
        }
        .padding(16)
        .outlinedSurface(cornerRadius: 22)
    }

    private func legend(_ status: VocabStatus, count: Int) -> some View {
        HStack(spacing: 6) {
            VocabStatusDot(status: status)
            Text("\(status.title) \(count)")
        }
        .accessibilityElement(children: .combine)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VocabularyListViewModel.Filter.allCases, id: \.self) { filter in
                    Button(filter.title) {
                        Task { await viewModel.setFilter(filter) }
                    }
                    .buttonStyle(SelectableChipStyle(isSelected: viewModel.filter == filter))
                    .accessibilityAddTraits(viewModel.filter == filter ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
        .padding(.top, 2)
    }

    @ViewBuilder
    private var wordList: some View {
        let visible = viewModel.entries
        HStack(spacing: 8) {
            Text("\(viewModel.totalItems) từ")
            if viewModel.isLoadingWords && !visible.isEmpty {
                ProgressView().controlSize(.small)
            }
        }
        .font(.footnote)
        .foregroundStyle(AppColor.textSecondary)
        .padding(.horizontal, 4)

        if visible.isEmpty {
            emptyWords
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { offset, entry in
                    if offset > 0 { GroupedDivider(leadingInset: 14) }
                    NavigationLink(value: VocabularyRoute.detail(entries: visible, index: offset)) {
                        VocabWordRow(entry: entry) { viewModel.play(entry.word) }
                    }
                    .buttonStyle(.plain)
                    .task { await viewModel.loadMoreIfNeeded(after: entry) }
                }
                loadMoreFooter
            }
            .padding(.vertical, 4)
            .outlinedSurface()
            .opacity(viewModel.isLoadingWords ? 0.5 : 1)
        }
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if viewModel.isLoadingMore {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 52)
        } else if viewModel.loadMoreFailed {
            Button("Không tải thêm được · Thử lại") {
                Task { await viewModel.retryLoadMore() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColor.brand)
            .frame(maxWidth: .infinity, minHeight: 52)
        }
    }

    @ViewBuilder
    private var emptyWords: some View {
        if viewModel.isLoadingWords {
            ProgressView().frame(maxWidth: .infinity, minHeight: 160)
        } else if let message = viewModel.errorMessage {
            VStack(spacing: 10) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Thử lại") { Task { await viewModel.retry() } }
                    .buttonStyle(SelectableChipStyle(isSelected: false, height: 40))
            }
            .frame(maxWidth: .infinity, minHeight: 160)
        } else {
            Text(viewModel.filter == .all
                 ? "Cấp này chưa có từ vựng."
                 : "Không có từ nào ở mục “\(viewModel.filter.title)”.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if let message = viewModel.errorMessage, !viewModel.isLoadingLevels {
            ContentUnavailableView {
                Label("Không tải được từ vựng", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Thử lại") { Task { await viewModel.retry() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 40)
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 240)
        }
    }

    // MARK: Actions

    private func refresh() {
        Task { await viewModel.refreshAfterLearning() }
    }

    private func startPendingQuiz() {
        guard let config = pendingQuiz else { return }
        pendingQuiz = nil
        quizLaunch = QuizLaunch(config: config)
    }

    private func handleAfterQuiz() {
        refresh()
        let action = afterQuiz
        afterQuiz = nil
        switch action {
        case .review(let words): flashcardSource = .words(words)
        case .newQuiz: isShowingQuizSetup = true
        case nil: break
        }
    }
}

/// Thanh tiến độ 3 đoạn: đã thuộc (xanh), đang học (cam), chưa học (nền).
struct VocabProgressBar: View {
    let summary: VocabSummary

    var body: some View {
        GeometryReader { proxy in
            let total = max(summary.total, 1)
            HStack(spacing: 2) {
                if summary.known > 0 {
                    Capsule().fill(VocabStatus.known.color)
                        .frame(width: proxy.size.width * CGFloat(summary.known) / CGFloat(total))
                }
                if summary.learning > 0 {
                    Capsule().fill(VocabStatus.learning.color)
                        .frame(width: proxy.size.width * CGFloat(summary.learning) / CGFloat(total))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 8)
        .background(Capsule().fill(AppColor.rowDivider))
        .clipShape(Capsule())
        .animation(.easeOut(duration: 0.3), value: summary)
        .accessibilityElement()
        .accessibilityLabel("Đã thuộc \(summary.known), đang học \(summary.learning), chưa học \(summary.notStarted) trên \(summary.total) từ")
    }
}

/// Một dòng từ: chấm trạng thái, chữ Hán, pinyin + nghĩa, nút nghe.
struct VocabWordRow: View {
    let entry: VocabEntry
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                VocabStatusDot(status: entry.status)
                Text(entry.word.hanzi)
                    .font(.hanzi(26))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 84, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.word.pinyin)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.brand)
                    Text(entry.word.meaning)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.word.hanzi), \(entry.word.pinyin), \(entry.word.meaning), \(entry.status.title)")
            SpeakerButton(accessibilityLabel: "Nghe phát âm \(entry.word.pinyin)", action: onPlay)
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }
}
