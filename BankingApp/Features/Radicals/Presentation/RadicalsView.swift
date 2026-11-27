import SwiftUI

/// Bộ thủ: Thường gặp / Tất cả 214, tìm kiếm, lọc số nét, lưới bộ thủ, khung chi tiết ở cuối màn.
struct RadicalsView: View {
    @State private var viewModel = RadicalsViewModel()
    @FocusState private var isSearchFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                modePicker
                searchField
                strokeFilters
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(viewModel.countText)
                        if viewModel.isLoading { ProgressView().controlSize(.small) }
                    }
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, 4)

                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let radical = viewModel.selected, !isSearchFocused {
                    RadicalDetailPanel(radical: radical)
                }
            }
        }
        .navigationTitle("Bộ thủ")
        .navigationBarTitleDisplayMode(.inline)
        // Đổi tab / số nét: tải ngay. Gõ tìm kiếm: đợi gõ xong.
        .task(id: viewModel.mode) { await viewModel.reload() }
        .task(id: viewModel.strokes) { await viewModel.reload() }
        .task(id: viewModel.search) { await viewModel.reload(debounce: true) }
    }

    // MARK: Bộ lọc

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(RadicalsViewModel.ListMode.allCases, id: \.self) { mode in
                let isSelected = viewModel.mode == mode
                Button {
                    viewModel.mode = mode
                } label: {
                    Text(mode.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : AppColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(Capsule().fill(isSelected ? AppColor.brand : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .outlinedSurface(Capsule())
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.textTertiary)
            TextField("Tìm bộ thủ, Hán Việt, nghĩa hoặc số bộ", text: $viewModel.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
            if !viewModel.search.isEmpty {
                Button {
                    viewModel.search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Xoá tìm kiếm")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .outlinedSurface(cornerRadius: 14, borderColor: isSearchFocused ? AppColor.brand : AppColor.fieldBorder,
                         lineWidth: isSearchFocused ? 2 : 1.5)
    }

    private var strokeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(RadicalStrokeFilter.allCases, id: \.self) { filter in
                    Button(filter.title) { viewModel.strokes = filter }
                        .buttonStyle(SelectableChipStyle(isSelected: viewModel.strokes == filter))
                        .accessibilityAddTraits(viewModel.strokes == filter ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: Lưới

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage, viewModel.items.isEmpty {
            VStack(spacing: 10) {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Thử lại") { Task { await viewModel.reload() } }
                    .buttonStyle(SelectableChipStyle(isSelected: false, height: 40))
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if viewModel.items.isEmpty && !viewModel.isLoading {
            Text("Không tìm thấy bộ thủ nào.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 160)
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.items) { radical in
                    RadicalCell(
                        radical: radical,
                        showsNumber: viewModel.mode == .all,
                        isSelected: radical.number == viewModel.selected?.number
                    ) {
                        isSearchFocused = false
                        viewModel.select(radical)
                    }
                }
            }
            .opacity(viewModel.isLoading ? 0.6 : 1)
        }
    }
}

private struct RadicalCell: View {
    let radical: Radical
    let showsNumber: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(radical.symbol)
                        .font(.hanzi(28, weight: .regular))
                        .foregroundStyle(isSelected ? AppColor.brand : AppColor.textPrimary)
                    if radical.isVariant {
                        Text(radical.canonical)
                            .font(.hanzi(14, weight: .regular))
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
                Text(radical.hanViet.capitalizedFirst)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(radical.meaning)
                    .font(.caption2)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 88)
            .overlay(alignment: .topLeading) {
                if showsNumber {
                    Text("#\(radical.number)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppColor.brand)
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                Text("\(radical.strokes) nét")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColor.textTertiary)
                    .padding(6)
            }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isSelected ? AppColor.brandTint : AppColor.fieldBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? AppColor.brand : AppColor.cardBorder, lineWidth: isSelected ? 2 : 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bộ \(radical.number), \(radical.symbol), \(radical.hanViet), \(radical.meaning), \(radical.strokes) nét")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RadicalDetailPanel: View {
    let radical: Radical

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(radical.symbol)
                    .font(.hanzi(34, weight: .regular))
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColor.brandTint))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\((radical.alias ?? radical.hanViet).capitalizedFirst) · \(radical.meaning)")
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !radical.examples.isEmpty {
                HStack(spacing: 8) {
                    ForEach(radical.examples.prefix(3), id: \.self) { example in
                        VStack(spacing: 1) {
                            Text(example.hanzi).font(.hanzi(22, weight: .regular))
                            Text([example.hanViet, example.meaning].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(AppColor.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xF4F6F9)))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(AppColor.fieldBackground))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(AppColor.cardBorder, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// "Bộ số 85 · 3 nét · dạng gốc 水 (4 nét) · Ba chấm thủy thường nằm bên trái chữ…"
    private var subtitle: String {
        var parts = ["Bộ số \(radical.number)", "\(radical.strokes) nét"]
        if radical.isVariant {
            parts.append("dạng gốc \(radical.canonical)" + (radical.canonicalStrokes.map { " (\($0) nét)" } ?? ""))
        }
        if let description = radical.description { parts.append(description) }
        return parts.joined(separator: " · ")
    }
}

private extension String {
    /// "thủy" → "Thủy".
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
