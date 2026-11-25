import SwiftUI

extension HomeViewModel.Tab {
    var title: String {
        switch self {
        case .home: return "Trang chủ"
        case .lessons: return "Bài học"
        case .review: return "Ôn tập"
        case .profile: return "Cá nhân"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .lessons: return "book"
        case .review: return "list.bullet.rectangle"
        case .profile: return "person"
        }
    }
}

/// Thanh tab nổi dạng viên thuốc, nền mờ.
struct FloatingTabBar: View {
    @Binding var selection: HomeViewModel.Tab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HomeViewModel.Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .frame(height: 64)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
        .shadow(color: .black.opacity(0.12), radius: 16, y: 12)
        .padding(.horizontal, 16)
    }

    private func tabButton(_ tab: HomeViewModel.Tab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.systemImage)
                    .symbolVariant(isSelected ? .fill : .none)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 26)
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isSelected ? AppColor.brand : Color(.secondaryLabel))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    Capsule().fill(AppColor.brandTint)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
