import SwiftUI

/// Một ô trong lưới "Công cụ" ở Trang chủ (tên ngắn + biểu tượng riêng theo thiết kế).
struct HomeTool: Identifiable, Hashable {
    enum Glyph: Hashable {
        case symbol(String)
        case text(String)
    }

    let kind: UtilityKind
    let shortTitle: String
    let fullTitle: String
    let glyph: Glyph
    let tint: Color

    var id: UtilityKind { kind }

    var utilityItem: UtilityItem {
        UtilityItem(id: kind.rawValue, kind: kind, title: fullTitle)
    }

    static let all: [HomeTool] = [
        HomeTool(kind: .dictionary, shortTitle: "Tra từ điển", fullTitle: "Tra từ điển",
                 glyph: .symbol("magnifyingglass"), tint: Color(.systemBlue)),
        HomeTool(kind: .pinyinChart, shortTitle: "Bảng Pinyin", fullTitle: "Bảng phiên âm Pinyin",
                 glyph: .text("ā"), tint: Color(.systemOrange)),
        HomeTool(kind: .tonePractice, shortTitle: "Thanh điệu", fullTitle: "Luyện thanh điệu",
                 glyph: .symbol("waveform"), tint: Color(.systemPink)),
        HomeTool(kind: .radicals, shortTitle: "Bộ thủ", fullTitle: "Bộ thủ",
                 glyph: .text("氵"), tint: Color(.systemIndigo)),
        HomeTool(kind: .hskVocabulary, shortTitle: "Từ vựng HSK", fullTitle: "Từ vựng HSK",
                 glyph: .symbol("rectangle.portrait.on.rectangle.portrait"), tint: Color(.systemPurple)),
    ]
}

/// Ô vuông màu chứa biểu tượng của công cụ.
struct HomeToolIcon: View {
    let tool: HomeTool
    var size: CGFloat = 34
    var hasShadow = false

    var body: some View {
        Group {
            switch tool.glyph {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.5, weight: .semibold))
            case .text(let text):
                Text(text)
                    .font(.system(size: size * 0.5, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(tool.tint, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        .shadow(color: hasShadow ? tool.tint.opacity(0.25) : .clear, radius: 6, y: 3)
        .accessibilityHidden(true)
    }
}

/// Ô công cụ trong lưới 3 cột: icon màu lớn + nhãn, không có khung bao (giống lưới app iPhone).
struct HomeToolTile: View {
    let tool: HomeTool

    var body: some View {
        VStack(spacing: 7) {
            HomeToolIcon(tool: tool, size: 56, hasShadow: true)
            Text(tool.shortTitle)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .top)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }
}

/// Danh sách đầy đủ các công cụ ("Tất cả").
struct AllToolsView: View {
    var body: some View {
        List(HomeTool.all) { tool in
            NavigationLink(value: tool) {
                HStack(spacing: 12) {
                    HomeToolIcon(tool: tool, size: 30)
                    Text(tool.fullTitle)
                }
            }
        }
        .navigationTitle("Công cụ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
