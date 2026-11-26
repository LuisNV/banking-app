import Foundation

/// Dữ liệu giả cho Từ vựng HSK khi chưa có API: giữ tiến độ trong bộ nhớ,
/// áp dụng đúng quy tắc chuyển trạng thái dự kiến của server.
actor MockVocabularyRepository: VocabularyRepository {
    private struct Progress {
        var status: VocabStatus
        var correctStreak = 0
        var dueAt = Date()
    }

    /// Số lần "Đã nhớ" liên tiếp để một từ thành "Đã thuộc".
    private static let knownStreak = 3
    private static let intervals: [Double] = [1, 3, 7, 14, 30]

    private let words: [VocabWord]
    private var progress: [String: Progress]
    private var attempts: [Int: QuizAttemptSummary] = [:]

    init(words: [VocabWord] = MockVocabularyData.hsk1) {
        self.words = words
        // Một vài từ đã học sẵn để màn danh sách có đủ 3 trạng thái.
        progress = [
            "hsk1-nihao": Progress(status: .known, correctStreak: 3),
            "hsk1-xiexie": Progress(status: .known, correctStreak: 4),
            "hsk1-baba": Progress(status: .known, correctStreak: 3),
            "hsk1-yi": Progress(status: .known, correctStreak: 3),
            "hsk1-zaijian": Progress(status: .learning, correctStreak: 1),
            "hsk1-mama": Progress(status: .learning),
            "hsk1-jintian": Progress(status: .learning, correctStreak: 2),
        ]
        attempts[1] = QuizAttemptSummary(correct: 7, total: 10, finishedAt: Date().addingTimeInterval(-86_400))
    }

    func availableLevels() async -> [Int] { [1] }

    func words(level: Int) async throws -> [VocabEntry] {
        try await latency()
        return words.filter { $0.level == level }.map { VocabEntry(word: $0, status: status(of: $0.id)) }
    }

    func summary(level: Int) async throws -> VocabSummary {
        let levelWords = words.filter { $0.level == level }
        let statuses = levelWords.map { status(of: $0.id) }
        return VocabSummary(
            total: levelWords.count,
            known: statuses.filter { $0 == .known }.count,
            learning: statuses.filter { $0 == .learning }.count
        )
    }

    func flashcards(level: Int, limit: Int, wordIDs: [String]?) async throws -> [VocabWord] {
        try await latency()
        if let wordIDs {
            return wordIDs.compactMap { id in words.first { $0.id == id } }
        }
        let now = Date()
        let levelWords = words.filter { $0.level == level }
        let due = levelWords.filter { progress[$0.id].map { $0.dueAt <= now } ?? false }
            .sorted { (progress[$0.id]?.status == .learning ? 0 : 1) < (progress[$1.id]?.status == .learning ? 0 : 1) }
        let fresh = levelWords.filter { progress[$0.id] == nil }
        var deck: [VocabWord] = []
        for word in due + fresh where deck.count < limit && !deck.contains(word) {
            deck.append(word)
        }
        return deck
    }

    func review(wordID: String, result: ReviewResult) async throws -> VocabStatus {
        var item = progress[wordID] ?? Progress(status: .learning)
        switch result {
        case .good:
            item.correctStreak += 1
            if item.correctStreak >= Self.knownStreak { item.status = .known }
            let index = min(item.correctStreak - 1, Self.intervals.count - 1)
            item.dueAt = Date().addingTimeInterval(Self.intervals[index] * 86_400)
        case .again:
            item.correctStreak = 0
            item.status = .learning
            item.dueAt = Date()
        }
        progress[wordID] = item
        return item.status
    }

    func setStatus(wordID: String, status: VocabStatus) async throws -> VocabStatus {
        switch status {
        case .notStarted:
            progress[wordID] = nil
        case .learning:
            progress[wordID] = Progress(status: .learning)
        case .known:
            progress[wordID] = Progress(
                status: .known,
                correctStreak: Self.knownStreak,
                dueAt: Date().addingTimeInterval(7 * 86_400)
            )
        }
        return status
    }

    func lastQuizAttempt(level: Int) async -> QuizAttemptSummary? {
        attempts[level]
    }

    func createQuiz(_ config: QuizConfig) async throws -> Quiz {
        try await latency()
        let levelWords = words.filter { $0.level == config.level }
        let pool: [VocabWord]
        switch config.scope {
        case .all: pool = levelWords
        case .learning: pool = levelWords.filter { status(of: $0.id) == .learning }
        case .known: pool = levelWords.filter { status(of: $0.id) == .known }
        case .topic(let topic): pool = levelWords.filter { $0.topic == topic }
        }
        let types = Array(config.types)
        guard !pool.isEmpty, !types.isEmpty else { throw VocabularyError.noWordsInScope }

        var picked = pool.shuffled()
        // Phạm vi ít từ hơn số câu: lặp lại từ (khác dạng câu) cho đủ.
        while picked.count < config.questionCount { picked += pool.shuffled() }
        let questions = picked.prefix(config.questionCount).enumerated().map { index, word in
            makeQuestion(id: "q\(index)", word: word, type: types.randomElement()!, levelWords: levelWords)
        }
        return Quiz(id: UUID().uuidString, questions: questions)
    }

    func submitQuiz(_ quiz: Quiz, answers: [QuizAnswer]) async throws -> QuizSubmission {
        try await latency()
        var correct = 0
        var statuses: [String: VocabStatus] = [:]
        for question in quiz.questions {
            let answer = answers.first { $0.questionID == question.id }
            let isCorrect = answer?.optionID == question.correctOptionID
            if isCorrect { correct += 1 }
            let current = status(of: question.word.id)
            if !isCorrect {
                statuses[question.word.id] = try await review(wordID: question.word.id, result: .again)
            } else if current == .notStarted {
                // Đúng một từ chưa học: có thể đoán mò, chỉ chuyển sang "Đang học".
                statuses[question.word.id] = try await setStatus(wordID: question.word.id, status: .learning)
            } else {
                statuses[question.word.id] = try await review(wordID: question.word.id, result: .good)
            }
        }
        let previous = attempts[quiz.questions.first?.word.level ?? 1]
        attempts[quiz.questions.first?.word.level ?? 1] = QuizAttemptSummary(
            correct: correct,
            total: quiz.questions.count,
            finishedAt: Date()
        )
        return QuizSubmission(
            correct: correct,
            total: quiz.questions.count,
            previousPercent: previous.map { $0.total > 0 ? $0.correct * 100 / $0.total : 0 },
            statuses: statuses
        )
    }

    // MARK: Helpers

    private func status(of wordID: String) -> VocabStatus {
        progress[wordID]?.status ?? .notStarted
    }

    private func makeQuestion(id: String, word: VocabWord, type: QuizQuestionType, levelWords: [VocabWord]) -> QuizQuestion {
        // Đáp án nhiễu: ưu tiên cùng chủ đề rồi mới tới cùng cấp, không trùng nội dung với đáp án đúng.
        let others = levelWords.filter { $0.id != word.id }
        let sameTopic = others.filter { $0.topic == word.topic }.shuffled()
        let rest = others.filter { $0.topic != word.topic }.shuffled()
        var distractors: [VocabWord] = []
        for candidate in sameTopic + rest where distractors.count < 3 {
            let text = optionText(candidate, type: type)
            if text != optionText(word, type: type) && !distractors.contains(where: { optionText($0, type: type) == text }) {
                distractors.append(candidate)
            }
        }
        let options = ([word] + distractors).shuffled().map {
            QuizOption(id: "\(id)-\($0.id)", text: optionText($0, type: type))
        }
        return QuizQuestion(id: id, type: type, word: word, options: options, correctOptionID: "\(id)-\(word.id)")
    }

    private func optionText(_ word: VocabWord, type: QuizQuestionType) -> String {
        type == .hanziToMeaning ? word.meaning : word.hanzi
    }

    private func latency() async throws {
        try await Task.sleep(for: .milliseconds(250))
    }
}
