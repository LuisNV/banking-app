import XCTest
@testable import BankingApp

final class MockVocabularyRepositoryTests: XCTestCase {
    private var repository: MockVocabularyRepository!

    override func setUp() {
        super.setUp()
        repository = MockVocabularyRepository()
    }

    func test_good_threeTimes_becomesKnown() async throws {
        let id = "hsk1-erzi"
        var status = try await repository.review(wordID: id, result: .good)
        XCTAssertEqual(status, .learning)
        status = try await repository.review(wordID: id, result: .good)
        XCTAssertEqual(status, .learning)
        status = try await repository.review(wordID: id, result: .good)
        XCTAssertEqual(status, .known)
    }

    func test_again_onKnownWord_goesBackToLearning() async throws {
        let status = try await repository.review(wordID: "hsk1-nihao", result: .again)
        XCTAssertEqual(status, .learning)
    }

    func test_summary_countsStatuses() async throws {
        _ = try await repository.setStatus(wordID: "hsk1-san", status: .known)
        let summary = try await repository.summary(level: 1)
        let words = try await repository.words(level: 1)
        XCTAssertEqual(summary.total, words.count)
        XCTAssertEqual(summary.known, words.filter { $0.status == .known }.count)
        XCTAssertEqual(summary.learning, words.filter { $0.status == .learning }.count)
        XCTAssertEqual(summary.notStarted, words.filter { $0.status == .notStarted }.count)
    }

    func test_createQuiz_hasRequestedCount_fourDistinctOptions_andOnlyEnabledTypes() async throws {
        var config = QuizConfig()
        config.questionCount = 20
        config.types = [.meaningToHanzi, .audioToHanzi]
        let quiz = try await repository.createQuiz(config)

        XCTAssertEqual(quiz.questions.count, 20)
        for question in quiz.questions {
            XCTAssertTrue(config.types.contains(question.type))
            XCTAssertEqual(question.options.count, 4)
            XCTAssertEqual(Set(question.options.map(\.text)).count, 4)
            XCTAssertEqual(question.options.filter { $0.id == question.correctOptionID }.first?.text, question.word.hanzi)
        }
    }

    func test_createQuiz_emptyScope_throws() async throws {
        let empty = MockVocabularyRepository(words: Array(MockVocabularyData.hsk1.prefix(4)))
        var config = QuizConfig()
        config.scope = .topic("Không có")
        do {
            _ = try await empty.createQuiz(config)
            XCTFail("Phải báo lỗi khi phạm vi không có từ")
        } catch {
            XCTAssertTrue(error is VocabularyError)
        }
    }

    func test_submitQuiz_wrongAnswer_movesWordToLearning_correctNewWord_onlyLearning() async throws {
        var config = QuizConfig()
        config.scope = .topic("Số đếm")
        config.questionCount = 2
        let quiz = try await repository.createQuiz(config)
        let first = quiz.questions[0], second = quiz.questions[1]
        let wrongOption = try XCTUnwrap(first.options.first { $0.id != first.correctOptionID })
        let answers = [
            QuizAnswer(questionID: first.id, optionID: wrongOption.id, elapsed: 1),
            QuizAnswer(questionID: second.id, optionID: second.correctOptionID, elapsed: 1),
        ]

        let result = try await repository.submitQuiz(quiz, answers: answers)

        XCTAssertEqual(result.total, 2)
        XCTAssertEqual(result.statuses[first.word.id], .learning)
        if first.word.id != second.word.id {
            XCTAssertEqual(result.correct, 1)
            // Số đếm: chỉ 一 đã thuộc sẵn, các từ khác chưa học → đúng chỉ thành "Đang học".
            let expected: VocabStatus = second.word.id == "hsk1-yi" ? .known : .learning
            XCTAssertEqual(result.statuses[second.word.id], expected)
        }
        XCTAssertEqual(result.previousPercent, 70)
    }
}

@MainActor
final class QuizViewModelTests: XCTestCase {
    func test_selectThenNext_throughAllQuestions_showsResult() async throws {
        var config = QuizConfig()
        config.questionCount = 3
        let viewModel = QuizViewModel(config: config, repository: MockVocabularyRepository(), pronunciation: SilentPronunciation())

        await viewModel.start()
        XCTAssertEqual(viewModel.phase, .question)

        for _ in 0..<3 {
            let question = try XCTUnwrap(viewModel.question)
            let correct = try XCTUnwrap(question.options.first { $0.id == question.correctOptionID })
            viewModel.select(correct)
            XCTAssertTrue(viewModel.isCorrect)
            await viewModel.next()
        }

        guard case .result(let submission) = viewModel.phase else {
            return XCTFail("Chưa sang màn kết quả")
        }
        XCTAssertEqual(submission.correct, 3)
        XCTAssertTrue(viewModel.wrongAnswers.isEmpty)
    }

    func test_cannotChangeAnswer_afterSelecting() async throws {
        let viewModel = QuizViewModel(config: QuizConfig(), repository: MockVocabularyRepository(), pronunciation: SilentPronunciation())
        await viewModel.start()
        let question = try XCTUnwrap(viewModel.question)
        viewModel.select(question.options[0])
        viewModel.select(question.options[1])
        XCTAssertEqual(viewModel.selectedOptionID, question.options[0].id)
        XCTAssertEqual(viewModel.answers.count, 1)
    }
}

private final class SilentPronunciation: PronunciationServiceProtocol {
    func speak(_ text: String, slow: Bool) {}
}
