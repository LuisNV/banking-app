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
        let levels = try await repository.levels()
        XCTAssertEqual(levels.map(\.level), Array(1...9))
        XCTAssertFalse(levels[1].isAvailable)
        let summary = levels[0].summary
        let words = try await repository.words(level: 1, status: nil, page: 0, size: 100).items
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
        // Hai từ chưa ai học: phạm vi "Đã thuộc" rỗng.
        let empty = MockVocabularyRepository(words: MockVocabularyData.hsk1.filter { ["hsk1-erzi", "hsk1-nver"].contains($0.id) })
        var config = QuizConfig()
        config.scope = .known
        do {
            _ = try await empty.createQuiz(config)
            XCTFail("Phải báo lỗi khi phạm vi không có từ")
        } catch {
            XCTAssertTrue(error is VocabularyError)
        }
    }

    func test_submitQuiz_wrongAnswer_movesWordToLearning_correctNewWord_onlyLearning() async throws {
        var config = QuizConfig()
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
            // Trả lời đúng: từ chưa học chỉ lên "Đang học", không bao giờ còn "Chưa học".
            XCTAssertNotEqual(result.statuses[second.word.id], .notStarted)
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
    func play(url: URL?, fallbackText text: String, slow: Bool) {}
}

// MARK: - Phân trang & lọc (mock theo đúng hợp đồng API)

final class MockVocabularyPagingTests: XCTestCase {
    func test_words_paging_andStatusFilter() async throws {
        let repository = MockVocabularyRepository()
        let first = try await repository.words(level: 1, status: nil, page: 0, size: 10)
        XCTAssertEqual(first.items.count, 10)
        XCTAssertEqual(first.totalItems, MockVocabularyData.hsk1.count)
        XCTAssertTrue(first.hasMore)

        let last = try await repository.words(level: 1, status: nil, page: first.totalPages - 1, size: 10)
        XCTAssertFalse(last.hasMore)

        let beyond = try await repository.words(level: 1, status: nil, page: 99, size: 10)
        XCTAssertTrue(beyond.items.isEmpty)

        let known = try await repository.words(level: 1, status: .known, page: 0, size: 50)
        XCTAssertTrue(known.items.allSatisfy { $0.status == .known })

        let empty = try await repository.words(level: 4, status: nil, page: 0, size: 50)
        XCTAssertEqual(empty.totalItems, 0)
    }

    func test_word_notFound_is404Code1026() async {
        let repository = MockVocabularyRepository()
        do {
            _ = try await repository.word(level: 1, entryNumber: 9999)
            XCTFail("Phải báo lỗi")
        } catch let NetworkError.api(code, httpStatus, _, _) {
            XCTAssertEqual(code, 1026)
            XCTAssertEqual(httpStatus, 404)
        } catch {
            XCTFail("Sai loại lỗi: \(error)")
        }
    }
}

// MARK: - DTO & repository API thật

final class HSKVocabularyDataTests: XCTestCase {
    private func decode<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try XCTUnwrap(decoder.decode(APIResponse<T>.self, from: Data(json.utf8)).data)
    }

    func test_decode_levels() throws {
        let levels = try decode("""
        {"code":0,"httpStatus":200,"message":"Thành công","traceId":"t","data":[
          {"level":1,"title":"Sơ cấp","available":true,"totalWords":300,"mastered":4,"learning":3,"notStarted":293},
          {"level":4,"title":"Trung cấp","available":false,"totalWords":0,"mastered":0,"learning":0,"notStarted":0}]}
        """, as: [HSKLevelDTO].self).map { $0.toDomain() }

        XCTAssertEqual(levels[0].summary, VocabSummary(total: 300, known: 4, learning: 3))
        XCTAssertEqual(levels[0].summary.notStarted, 293)
        XCTAssertEqual(levels[0].title, "Sơ cấp")
        XCTAssertTrue(levels[0].isAvailable)
        XCTAssertFalse(levels[1].isAvailable)
    }

    func test_decode_wordPage_resolvesAudioAgainstServerOrigin() throws {
        let origin = HSKVocabularyMapping.serverOrigin(of: URL(string: "http://localhost:8081/api")!)
        let page = try decode("""
        {"code":0,"httpStatus":200,"message":"Thành công","traceId":"t","data":{
          "items":[
            {"entryNumber":1,"hanzi":"爱","pinyin":"ài","meaningVi":"yêu","audioUrl":"/audio/hsk/3.0-2025/1/1.m4a","status":"NOT_STARTED"},
            {"entryNumber":4,"hanzi":"爸爸","pinyin":"bàba","meaningVi":"bố","audioUrl":null,"status":"MASTERED"}],
          "page":0,"size":50,"totalItems":300,"totalPages":6}}
        """, as: HSKWordPageDTO.self).toDomain(level: 1, audioBaseURL: origin)

        XCTAssertEqual(page.items[0].word.audioURL?.absoluteString, "http://localhost:8081/audio/hsk/3.0-2025/1/1.m4a")
        XCTAssertEqual(page.items[0].status, .notStarted)
        XCTAssertFalse(page.items[0].word.hasDetail)
        XCTAssertNil(page.items[1].word.audioURL)
        XCTAssertEqual(page.items[1].status, .known)
        XCTAssertEqual(page.items[1].word.entryNumber, 4)
        XCTAssertTrue(page.hasMore)
    }

    func test_decode_detail_withNulls() throws {
        let origin = URL(string: "http://localhost:8081/")!
        let entry = try decode("""
        {"code":0,"httpStatus":200,"message":"Thành công","traceId":"t","data":{
          "entryNumber":147,"level":1,"hanzi":"你好","pinyin":"nǐ hǎo","meaningVi":"xin chào",
          "audioUrl":"/audio/hsk/3.0-2025/1/147.m4a","status":"LEARNING",
          "hanViet":"nhĩ hảo","hanVietNote":null,"wordType":"Cụm từ","usageNote":"",
          "examples":[{"sentenceZh":"你好，我叫明安。","pinyin":"Nǐ hǎo, wǒ jiào Míng'ān.","translationVi":"Xin chào, tôi tên là Minh An.","note":null}]}}
        """, as: HSKWordDetailDTO.self).toDomain(audioBaseURL: origin)

        XCTAssertEqual(entry.status, .learning)
        XCTAssertEqual(entry.word.hanViet, "nhĩ hảo")
        XCTAssertNil(entry.word.hanVietNote)
        XCTAssertNil(entry.word.usageNote, "Chuỗi rỗng coi như không có")
        XCTAssertEqual(entry.word.partOfSpeech, "Cụm từ")
        XCTAssertEqual(entry.word.examples.count, 1)
        XCTAssertTrue(entry.word.hasDetail)
        XCTAssertEqual(entry.word.id, "hsk1-147")
    }

    func test_endpoint_wordsQuery() {
        let all = HSKVocabularyEndpoint.words(level: 1, status: nil, page: 0, size: 50)
        XCTAssertEqual(all.path, "v1/hsk/levels/1/words")
        XCTAssertEqual(all.queryItems, ["page": "0", "size": "50"])
        let learning = HSKVocabularyEndpoint.words(level: 1, status: "LEARNING", page: 2, size: 50)
        XCTAssertEqual(learning.queryItems?["status"], "LEARNING")
        XCTAssertEqual(HSKVocabularyEndpoint.word(level: 1, entryNumber: 147).path, "v1/hsk/levels/1/words/147")
    }

    func test_repositoryImpl_quizUsesAllPages_andProgressIsReadOnly() async throws {
        let remote = StubHSKRemote(totalWords: 230)
        let repository = VocabularyRepositoryImpl(remote: remote, apiBaseURL: URL(string: "http://localhost:8081/api")!)

        var config = QuizConfig()
        config.questionCount = 10
        let quiz = try await repository.createQuiz(config)
        XCTAssertEqual(quiz.questions.count, 10)
        let pagesRequested = await remote.requestedPages
        XCTAssertEqual(pagesRequested, [0, 1, 2], "230 từ, mỗi trang 100 → 3 trang")

        let answers = quiz.questions.map { QuizAnswer(questionID: $0.id, optionID: $0.correctOptionID, elapsed: 1) }
        let result = try await repository.submitQuiz(quiz, answers: answers)
        XCTAssertEqual(result.correct, 10)
        XCTAssertTrue(result.statuses.isEmpty)
        XCTAssertFalse(repository.canUpdateProgress)
        do {
            _ = try await repository.review(wordID: "hsk1-1", result: .good)
            XCTFail("Chưa có API ghi tiến độ")
        } catch {
            XCTAssertEqual(error as? VocabularyError, .progressNotSupported)
        }
    }
}

private actor StubHSKRemote: HSKVocabularyRemoteDataSource {
    let totalWords: Int
    private(set) var requestedPages: [Int] = []

    init(totalWords: Int) {
        self.totalWords = totalWords
    }

    func levels() async throws -> [HSKLevelDTO] {
        [HSKLevelDTO(level: 1, title: "Sơ cấp", available: true, totalWords: totalWords, mastered: 0, learning: 0, notStarted: totalWords)]
    }

    func words(level: Int, status: String?, page: Int, size: Int) async throws -> HSKWordPageDTO {
        requestedPages.append(page)
        let start = page * size
        let end = min(start + size, totalWords)
        let items = start < end ? (start..<end).map {
            HSKWordItemDTO(entryNumber: $0 + 1, hanzi: "字\($0)", pinyin: "zi\($0)", meaningVi: "nghĩa \($0)", audioUrl: nil, status: nil)
        } : []
        return HSKWordPageDTO(items: items, page: page, size: size, totalItems: totalWords, totalPages: (totalWords + size - 1) / size)
    }

    func word(level: Int, entryNumber: Int) async throws -> HSKWordDetailDTO {
        throw NetworkError.api(code: 1026, httpStatus: 404, message: "Không tìm thấy từ vựng", traceId: nil)
    }
}
