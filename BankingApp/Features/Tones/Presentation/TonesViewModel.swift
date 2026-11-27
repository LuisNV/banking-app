import Factory
import Foundation
import Observation

@Observable
@MainActor
final class TonesViewModel {
    private(set) var guide: ToneGuide?
    private(set) var guideError: String?
    private(set) var questions: [TonePracticeQuestion] = []
    private(set) var practiceError: String?
    private(set) var isLoadingPractice = false
    private(set) var index = 0
    private(set) var pickedTone: Int?
    private(set) var score = 0

    private let repository: any TonesRepository
    private let pronunciation: any PronunciationServiceProtocol

    init(
        repository: any TonesRepository = Container.shared.tonesRepository(),
        pronunciation: any PronunciationServiceProtocol = Container.shared.pronunciationService()
    ) {
        self.repository = repository
        self.pronunciation = pronunciation
    }

    var question: TonePracticeQuestion? { index < questions.count ? questions[index] : nil }
    var isAnswered: Bool { pickedTone != nil }
    var isCorrect: Bool { pickedTone != nil && pickedTone == question?.correctTone }
    var isFinished: Bool { !questions.isEmpty && index >= questions.count }
    var roundText: String { "Câu \(min(index + 1, questions.count))/\(questions.count) · Đúng \(score)" }

    func load() async {
        async let guideTask: Void = loadGuide()
        async let practiceTask: Void = loadPractice()
        _ = await (guideTask, practiceTask)
    }

    func loadGuide() async {
        guard guide == nil else { return }
        do {
            guide = try await repository.guide()
            guideError = nil
        } catch {
            guideError = error.localizedDescription
        }
    }

    /// Lượt luyện mới: 10 câu ngẫu nhiên từ server.
    func loadPractice() async {
        guard !isLoadingPractice else { return }
        isLoadingPractice = true
        practiceError = nil
        defer { isLoadingPractice = false }
        do {
            let newQuestions = try await repository.practice()
            questions = newQuestions
            index = 0
            pickedTone = nil
            score = 0
        } catch {
            practiceError = error.localizedDescription
        }
    }

    func playTone(_ tone: ToneInfo) {
        pronunciation.play(url: tone.audioURL, fallbackText: "", slow: false)
    }

    /// Phát cả từ (server không tách audio từng âm tiết).
    func playQuestion() {
        guard let question else { return }
        pronunciation.play(url: question.audioURL, fallbackText: question.hanzi, slow: false)
    }

    func pick(_ tone: Int) {
        guard !isAnswered, let question else { return }
        pickedTone = tone
        if tone == question.correctTone { score += 1 }
    }

    func next() {
        guard isAnswered else { return }
        index += 1
        pickedTone = nil
        if question != nil { playQuestion() }
    }
}
