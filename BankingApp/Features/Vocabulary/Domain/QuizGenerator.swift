import Foundation

/// Tạo đề và chấm bài kiểm tra trên máy (dùng chung cho bản mock và bản API thật
/// khi server chưa có API kiểm tra).
enum QuizGenerator {
    /// - Parameters:
    ///   - pool: các từ trong phạm vi đã chọn (Tất cả / Đang học / Đã thuộc).
    ///   - levelWords: mọi từ của cấp, để lấy đáp án nhiễu.
    static func make(_ config: QuizConfig, pool: [VocabWord], levelWords: [VocabWord]) throws -> Quiz {
        let types = Array(config.types)
        guard !pool.isEmpty, !types.isEmpty else { throw VocabularyError.noWordsInScope }
        guard levelWords.count >= 4 else { throw VocabularyError.notEnoughWords }

        var picked = pool.shuffled()
        // Phạm vi ít từ hơn số câu: lặp lại từ (thường khác dạng câu) cho đủ.
        while picked.count < config.questionCount { picked += pool.shuffled() }
        let questions = picked.prefix(config.questionCount).enumerated().map { index, word in
            makeQuestion(id: "q\(index)", word: word, type: types.randomElement()!, levelWords: levelWords)
        }
        return Quiz(id: UUID().uuidString, questions: questions)
    }

    static func correctCount(_ quiz: Quiz, answers: [QuizAnswer]) -> Int {
        quiz.questions.filter { question in
            answers.first { $0.questionID == question.id }?.optionID == question.correctOptionID
        }.count
    }

    private static func makeQuestion(id: String, word: VocabWord, type: QuizQuestionType, levelWords: [VocabWord]) -> QuizQuestion {
        // Đáp án nhiễu: ưu tiên cùng chủ đề (nếu có) rồi tới cùng cấp, không trùng nội dung với đáp án đúng.
        let others = levelWords.filter { $0.id != word.id }.shuffled()
        let sameTopic = word.topic == nil ? [] : others.filter { $0.topic == word.topic }
        let rest = others.filter { word.topic == nil || $0.topic != word.topic }
        let answerText = optionText(word, type: type)
        var distractors: [String] = []
        for candidate in sameTopic + rest where distractors.count < 3 {
            let text = optionText(candidate, type: type)
            if text != answerText && !distractors.contains(text) {
                distractors.append(text)
            }
        }
        let correctID = "\(id)-answer"
        let options = ([QuizOption(id: correctID, text: answerText)]
            + distractors.enumerated().map { QuizOption(id: "\(id)-\($0.offset)", text: $0.element) })
            .shuffled()
        return QuizQuestion(id: id, type: type, word: word, options: options, correctOptionID: correctID)
    }

    private static func optionText(_ word: VocabWord, type: QuizQuestionType) -> String {
        type == .hanziToMeaning ? word.meaning : word.hanzi
    }
}
