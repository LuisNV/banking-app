import Factory
import Foundation
import Observation

@Observable
@MainActor
final class PinyinChartViewModel {
    enum Tab: CaseIterable, Hashable {
        case initials, finals, combinations

        var title: String {
            switch self {
            case .initials: return "Thanh mẫu"
            case .finals: return "Vận mẫu"
            case .combinations: return "Ghép âm"
            }
        }
    }

    private(set) var chart: PinyinChart?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var tab: Tab = .initials
    /// Âm đang chọn của từng tab (giữ lại khi đổi tab qua lại).
    private(set) var selectedInitialSound: String?
    private(set) var selectedFinalSound: String?
    /// Tab Ghép âm: thanh mẫu đang xem và âm tiết đang chọn.
    private(set) var combinationInitial: String?
    private(set) var selectedCombination: PinyinCombination?

    private let repository: any PinyinRepository
    private let pronunciation: any PronunciationServiceProtocol

    init(
        repository: any PinyinRepository = Container.shared.pinyinRepository(),
        pronunciation: any PronunciationServiceProtocol = Container.shared.pronunciationService()
    ) {
        self.repository = repository
        self.pronunciation = pronunciation
    }

    var groups: [PinyinGroup] {
        switch tab {
        case .initials: return chart?.initials ?? []
        case .finals: return chart?.finals ?? []
        case .combinations: return []
        }
    }

    /// Âm đang chọn ở tab Thanh mẫu / Vận mẫu (mặc định âm đầu tiên).
    var selectedSound: PinyinSound? {
        let all = groups.flatMap(\.sounds)
        let id = tab == .initials ? selectedInitialSound : selectedFinalSound
        return all.first { $0.symbol == id } ?? all.first
    }

    /// Thanh mẫu có trong danh sách ghép, theo thứ tự server trả ("" = không thanh mẫu, xếp cuối).
    var combinationInitials: [String] {
        var seen: [String] = []
        for combination in chart?.combinations ?? [] where !seen.contains(combination.initial) {
            seen.append(combination.initial)
        }
        if let empty = seen.firstIndex(of: "") {
            seen.append(seen.remove(at: empty))
        }
        return seen
    }

    var currentCombinationInitial: String? { combinationInitial ?? combinationInitials.first }

    var combinationsForInitial: [PinyinCombination] {
        guard let initial = currentCombinationInitial else { return [] }
        return (chart?.combinations ?? []).filter { $0.initial == initial }
    }

    var currentCombination: PinyinCombination? {
        if let selectedCombination, selectedCombination.initial == currentCombinationInitial {
            return selectedCombination
        }
        return combinationsForInitial.first
    }

    var totalCombinations: Int { chart?.combinations.count ?? 0 }

    /// Âm thanh mẫu tương ứng (để hiện mẹo ở tab Ghép âm).
    func initialSound(_ symbol: String) -> PinyinSound? {
        chart?.initials.flatMap(\.sounds).first { $0.symbol == symbol }
    }

    func load() async {
        guard chart == nil, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            chart = try await repository.chart()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func select(_ sound: PinyinSound) {
        switch tab {
        case .initials: selectedInitialSound = sound.symbol
        case .finals: selectedFinalSound = sound.symbol
        case .combinations: break
        }
        play(sound)
    }

    func selectCombinationInitial(_ initial: String) {
        combinationInitial = initial
        selectedCombination = nil
    }

    func select(_ combination: PinyinCombination) {
        selectedCombination = combination
    }

    func play(_ sound: PinyinSound) {
        // Không có audio thì đọc chữ ví dụ bằng giọng của máy; không có chữ thì thôi.
        guard sound.audioURL != nil || sound.exampleHanzi != nil else { return }
        pronunciation.play(url: sound.audioURL, fallbackText: sound.exampleHanzi ?? "", slow: false)
    }
}
