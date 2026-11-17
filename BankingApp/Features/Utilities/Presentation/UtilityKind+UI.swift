import SwiftUI

extension UtilityKind {
    var systemImage: String {
        switch self {
        case .dictionary: return "magnifyingglass"
        case .pinyinChart: return "textformat.abc"
        case .tonePractice: return "mic.fill"
        case .handwriting: return "pencil.tip"
        case .radicals: return "square.grid.2x2.fill"
        case .hskVocabulary: return "book.closed.fill"
        }
    }

    var tint: Color {
        switch self {
        case .dictionary: return AppColor.brand
        case .pinyinChart: return Color(.systemOrange)
        case .tonePractice: return Color(.systemGreen)
        case .handwriting: return Color(.systemRed)
        case .radicals: return Color(.systemPurple)
        case .hskVocabulary: return Color(.systemIndigo)
        }
    }
}
