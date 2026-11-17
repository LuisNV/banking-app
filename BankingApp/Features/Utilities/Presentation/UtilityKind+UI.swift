import SwiftUI

extension UtilityKind {
    var systemImage: String {
        switch self {
        case .qrPayment: return "qrcode.viewfinder"
        case .exchangeRate: return "chart.bar.fill"
        case .savingsRate: return "percent"
        case .atmLocator: return "mappin.and.ellipse"
        case .promotions: return "gift.fill"
        case .loanCalculator: return "function"
        }
    }

    var tint: Color {
        switch self {
        case .qrPayment: return AppColor.brand
        case .exchangeRate: return Color(.systemOrange)
        case .savingsRate: return Color(.systemGreen)
        case .atmLocator: return Color(.systemRed)
        case .promotions: return Color(.systemPurple)
        case .loanCalculator: return Color(.systemIndigo)
        }
    }
}
