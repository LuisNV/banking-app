import Factory
import Foundation
import Observation

@Observable
@MainActor
final class QuizViewModel {
    enum Phase: Equatable {
        case loading
        case failed(String)
        case question
        case submitting
        case result(QuizSubmission)
    }

    struct WrongAnswer: Identifiable {
        let word: VocabWord
        let chosenText: String
        let type: QuizQuestionType
        var id: String { word.id + type.rawValue }
    }

    let config: QuizConfig
    private(set) var phase: Phase = .loading
    private(set) var quiz: Quiz?
    private(set) var index = 0
    private(set) var selectedOptionID: String?
    private(set) var answers: [QuizAnswer] = []
    private(set) var startedAt = Date()
    private(set) var finishedAt: Date?
    private var questionShownAt = Date()

    private let repository: any VocabularyRepository
    private let pronunciation: any PronunciationServiceProtocol

    init(
        config: QuizConfig,
        repository: any VocabularyRepository = Container.shared.vocabularyRepository(),
        pronunciation: any PronunciationServiceProtocol = Container.shared.pronunciationService()
    ) {
        self.config = config
        self.repository = repository
        self.pronunciation = pronunciation
    }

    var question: QuizQuestion? {
        guard let quiz, index < quiz.questions.count else { return nil }
        return quiz.questions[index]
    }

    var total: Int { quiz?.questions.count ?? config.questionCount }
    var number: Int { min(index + 1, total) }
    var progress: Double { total == 0 ? 0 : Double(index + (isAnswered ? 1 : 0)) / Double(total) }
    var isAnswered: Bool { selectedOptionID != nil }
    var isCorrect: Bool { selectedOptionID != nil && selectedOptionID == question?.correctOptionID }
    var isLastQuestion: Bool { index >= total - 1 }

    var wrongAnswers: [WrongAnswer] {
        guard let quiz else { return [] }
        return quiz.questions.compactMap { question in
            guard let answer = answers.first(where: { $0.questionID == question.id }),
                  answer.optionID != question.correctOptionID else { return nil }
            let chosen = question.options.first { $0.id == answer.optionID }?.text ?? "—"
            return WrongAnswer(word: question.word, chosenText: chosen, type: question.type)
        }
    }

    var duration: TimeInterval { (finishedAt ?? Date()).timeIntervalSince(startedAt) }

    func start() async {
        guard quiz == nil else { return }
        phase = .loading
        do {
            quiz = try await repository.createQuiz(config)
            startedAt = Date()
            questionShownAt = Date()
            phase = .question
            playIfAudio()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func retryStart() async {
        quiz = nil
        await start()
    }

    func select(_ option: QuizOption) {
        guard !isAnswered, let question else { return }
        selectedOptionID = option.id
        answers.append(QuizAnswer(
            questionID: question.id,
            optionID: option.id,
            elapsed: Date().timeIntervalSince(questionShownAt)
        ))
    }

    func next() async {
        guard isAnswered else { return }
        if isLastQuestion {
            await submit()
        } else {
            index += 1
            selectedOptionID = nil
            questionShownAt = Date()
            playIfAudio()
        }
    }

    func playWord(slow: Bool = false) {
        guard let question else { return }
        pronunciation.play(url: question.word.audioURL, fallbackText: question.word.hanzi, slow: slow)
    }

    func play(_ word: VocabWord) {
        pronunciation.play(url: word.audioURL, fallbackText: word.hanzi, slow: false)
    }

    private func submit() async {
        guard let quiz else { return }
        finishedAt = Date()
        phase = .submitting
        do {
            phase = .result(try await repository.submitQuiz(quiz, answers: answers))
        } catch {
            // Không nộp được: vẫn hiện kết quả tự chấm, không cập nhật tiến độ.
            let correct = quiz.questions.count - wrongAnswers.count
            phase = .result(QuizSubmission(correct: correct, total: quiz.questions.count, previousPercent: nil, statuses: [:]))
        }
    }

    private func playIfAudio() {
        if question?.type == .audioToHanzi { playWord() }
    }
}
