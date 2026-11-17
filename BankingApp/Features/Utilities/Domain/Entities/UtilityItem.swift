import Foundation

/// Loại tiện ích. Domain chỉ giữ loại; icon/màu do Presentation quyết định.
enum UtilityKind: String, CaseIterable {
    case qrPayment
    case exchangeRate
    case savingsRate
    case atmLocator
    case promotions
    case loanCalculator
}

struct UtilityItem: Identifiable, Equatable, Hashable {
    let id: String
    let kind: UtilityKind
    let title: String
}

struct SupportContact: Equatable {
    let title: String
    let hotline: String

    var phoneURL: URL? {
        URL(string: "tel:\(hotline.filter(\.isNumber))")
    }
}
