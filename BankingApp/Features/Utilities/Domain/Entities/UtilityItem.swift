import Foundation

/// Loại tiện ích học thử. Domain chỉ giữ loại; icon/màu do Presentation quyết định.
enum UtilityKind: String, CaseIterable {
    case dictionary
    case pinyinChart
    case tonePractice
    case handwriting
    case radicals
    case hskVocabulary
}

struct UtilityItem: Identifiable, Equatable, Hashable {
    let id: String
    let kind: UtilityKind
    let title: String
}

struct SupportContact: Equatable {
    let title: String
    let email: String

    var mailURL: URL? {
        URL(string: "mailto:\(email)")
    }
}
