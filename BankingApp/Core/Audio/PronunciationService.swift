import AVFoundation

protocol PronunciationServiceProtocol {
    /// Đọc to một từ tiếng Trung bằng giọng đọc của máy. `slow`: đọc chậm.
    func speak(_ text: String, slow: Bool)
    /// Phát file audio của từ; không có `url` (hoặc phát lỗi) thì đọc `text` bằng giọng của máy.
    func play(url: URL?, fallbackText text: String, slow: Bool)
}

extension PronunciationServiceProtocol {
    func speak(_ text: String) { speak(text, slow: false) }
}

/// Phát âm: ưu tiên file audio của server, dự phòng bằng giọng đọc có sẵn của iOS (zh-CN).
final class PronunciationService: NSObject, PronunciationServiceProtocol {
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVPlayer?
    private var failureObserver: NSObjectProtocol?

    func speak(_ text: String, slow: Bool) {
        stopAll()
        configureSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.45 : 0.8)
        synthesizer.speak(utterance)
    }

    func play(url: URL?, fallbackText text: String, slow: Bool) {
        guard let url else { return speak(text, slow: slow) }
        stopAll()
        configureSession()
        let item = AVPlayerItem(url: url)
        // Không tải được file (mất mạng, 404…): đọc bằng giọng của máy.
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            self?.speak(text, slow: slow)
        }
        let statusObservation = item.observe(\.status) { [weak self] item, _ in
            if item.status == .failed {
                DispatchQueue.main.async { self?.speak(text, slow: slow) }
            }
        }
        observations = [statusObservation]
        let player = AVPlayer(playerItem: item)
        self.player = player
        player.playImmediately(atRate: slow ? 0.6 : 1)
    }

    private var observations: [NSKeyValueObservation] = []

    private func stopAll() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        player?.pause()
        player = nil
        observations = []
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
            self.failureObserver = nil
        }
    }

    /// Phát cả khi gạt nút im lặng (người dùng chủ động bấm nghe).
    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
