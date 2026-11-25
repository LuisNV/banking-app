import AVFoundation

protocol PronunciationServiceProtocol {
    /// Đọc to một từ tiếng Trung.
    func speak(_ text: String)
}

/// Phát âm bằng giọng đọc có sẵn của iOS (zh-CN). Thay bằng file audio thật khi có API.
final class PronunciationService: PronunciationServiceProtocol {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
        synthesizer.speak(utterance)
    }
}
