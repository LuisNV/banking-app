import Factory
import Foundation
import Observation

@Observable
@MainActor
final class RadicalsViewModel {
    enum ListMode: CaseIterable, Hashable {
        case common, all

        var title: String {
            switch self {
            case .common: return "Thường gặp"
            case .all: return "Tất cả 214"
            }
        }
    }

    var mode: ListMode = .common
    var search = ""
    var strokes: RadicalStrokeFilter = .all
    private(set) var items: [Radical] = []
    private(set) var total = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var selectedNumber: Int?
    private var loadedQuery: RadicalQuery?
    /// Lượt tải đang chạy (các `.task` mở màn cùng lúc không gọi trùng).
    private var inFlightQuery: RadicalQuery?

    private let repository: any RadicalsRepository

    init(repository: any RadicalsRepository = Container.shared.radicalsRepository()) {
        self.repository = repository
    }

    var query: RadicalQuery {
        RadicalQuery(commonOnly: mode == .common, search: search, strokes: strokes)
    }

    var selected: Radical? {
        items.first { $0.number == selectedNumber } ?? items.first
    }

    var countText: String {
        let isFiltered = !search.trimmingCharacters(in: .whitespaces).isEmpty || strokes != .all
        if isFiltered { return "\(total) bộ phù hợp" }
        return mode == .common ? "\(total) bộ thường gặp nhất trong HSK 1–3" : "\(total) bộ · thứ tự Khang Hy, theo số nét"
    }

    /// Tải theo bộ lọc hiện tại. `debounce`: chờ người dùng gõ xong (ô tìm kiếm).
    func reload(debounce: Bool = false) async {
        let current = query
        if debounce {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, current == query else { return }
        }
        guard current != loadedQuery || errorMessage != nil, current != inFlightQuery else { return }
        inFlightQuery = current
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            if inFlightQuery == current { inFlightQuery = nil }
        }
        do {
            let result = try await repository.radicals(current)
            // Bỏ kết quả về muộn của bộ lọc cũ.
            guard current == query else { return }
            items = result.items
            total = result.total
            loadedQuery = current
            if !items.contains(where: { $0.number == selectedNumber }) {
                selectedNumber = items.first?.number
            }
        } catch {
            guard current == query else { return }
            errorMessage = error.localizedDescription
        }
    }

    func select(_ radical: Radical) {
        selectedNumber = radical.number
    }
}
