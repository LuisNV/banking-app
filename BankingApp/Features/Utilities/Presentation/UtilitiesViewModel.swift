import Factory
import Foundation
import Observation

@MainActor
@Observable
final class UtilitiesViewModel {
    private(set) var items: [UtilityItem] = []
    private(set) var support: SupportContact?
    private(set) var isLoading = false
    var selectedItem: UtilityItem?

    private let getUtilitiesUseCase: GetPublicUtilitiesUseCaseProtocol

    init(getUtilitiesUseCase: GetPublicUtilitiesUseCaseProtocol = Container.shared.getPublicUtilitiesUseCase()) {
        self.getUtilitiesUseCase = getUtilitiesUseCase
    }

    func load() async {
        guard items.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        if let result = try? await getUtilitiesUseCase.execute() {
            items = result.items
            support = result.support
        }
    }

    func select(_ item: UtilityItem) {
        selectedItem = item
    }
}
