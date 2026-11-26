import AVFoundation

protocol PronunciationServiceProtocol {
    /// Đọc to một từ tiếng Trung. `slow`: đọc chậm (nghe lại trong bài kiểm tra).
    func speak(_ text: String, slow: Bool)
}

extension PronunciationServiceProtocol {
    func speak(_ text: String) { speak(text, slow: false) }
}

/// Phát âm bằng giọng đọc có sẵn của iOS (zh-CN). Thay bằng file audio thật khi có API.
final class PronunciationService: PronunciationServiceProtocol {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, slow: Bool) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.45 : 0.8)
        synthesizer.speak(utterance)
    }
}
