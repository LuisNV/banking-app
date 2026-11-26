import SwiftUI
import UIKit

/// Màn cài đặt học đang mở từ tab Cá nhân.
enum LearningSettingsScreen: String, Identifiable {
    case dailyGoal, reminder, script
    var id: String { rawValue }
}

// MARK: - Khung chung

/// Khung chung: thanh trên có nút quay lại + tiêu đề, nút Lưu ở dưới, hộp báo lỗi.
private struct SettingsScaffold<Content: View>: View {
    let title: String
    let saveTitle: String
    let canSave: Bool
    let onSave: () async throws -> Void
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
            .background(AppColor.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left").fontWeight(.semibold)
                    }
                    .accessibilityLabel("Quay lại")
                    .disabled(isSaving)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(isSaving ? "Đang lưu…" : saveTitle) {
                    Task { await save() }
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: isSaving, isPill: true))
                .disabled(!canSave || isSaving)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppColor.background)
            }
            .alert(
                "Không thể lưu",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                presenting: errorMessage
            ) { _ in
                Button("Đóng", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await onSave()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? LearningSettingsError.unknown.errorDescription
        }
    }
}

private struct SelectionCheck: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(AppColor.brand)
            .accessibilityHidden(true)
    }
}

// MARK: - Mục tiêu mỗi ngày

struct DailyGoalSettingsView: View {
    let store: LearningSettingsStore
    /// Chuỗi ngày học hiện tại (nếu có) để nhắc người dùng.
    var streakDays: Int?

    @State private var selected = LearningSettings.default.dailyGoalMinutes
    @State private var didLoad = false

    private var options: [Int] {
        var values = LearningSettings.goalPresets
        let current = store.settings.dailyGoalMinutes
        if !values.contains(current) { values.append(current) }
        return values.sorted()
    }

    var body: some View {
        SettingsScaffold(
            title: "Mục tiêu mỗi ngày",
            saveTitle: "Lưu mục tiêu",
            canSave: selected != store.settings.dailyGoalMinutes
        ) {
            var updated = store.settings
            updated.dailyGoalMinutes = selected
            try await store.save(updated)
        } content: {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    GoalRing(minutes: selected)
                    Text("Học một chút mỗi ngày giúp bạn nhớ lâu hơn học dồn một lần.")
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    FormSectionTitle("Chọn mục tiêu")
                    GroupedCard {
                        ForEach(Array(options.enumerated()), id: \.element) { index, minutes in
                            if index > 0 { GroupedDivider(leadingInset: 16) }
                            Button {
                                selected = minutes
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(minutes) phút").font(.body.weight(.semibold))
                                        Text(Self.hint(for: minutes))
                                            .font(.footnote)
                                            .foregroundStyle(AppColor.textSecondary)
                                    }
                                    Spacer()
                                    if minutes == selected { SelectionCheck() }
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 56)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(minutes == selected ? [.isSelected] : [])
                        }
                    }
                }

                if let streakDays, streakDays > 0 {
                    HStack(spacing: 12) {
                        StreakIcon()
                        Text("Đạt mục tiêu mỗi ngày để giữ chuỗi học. Chuỗi hiện tại của bạn: **\(streakDays) ngày**.")
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(Color(.systemOrange).opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            selected = store.settings.dailyGoalMinutes
        }
    }

    static func hint(for minutes: Int) -> String {
        switch minutes {
        case ..<10: return "Nhẹ nhàng · vài từ mới mỗi ngày"
        case ..<15: return "Thoải mái · một phần bài học"
        case ..<20: return "Đều đặn · khoảng một bài học"
        case ..<30: return "Nghiêm túc · bài học và ôn tập"
        case ..<45: return "Chăm chỉ · học sâu mỗi ngày"
        default: return "Tuỳ chỉnh"
        }
    }
}

private struct GoalRing: View {
    let minutes: Int

    var body: some View {
        ZStack {
            Circle().stroke(Color(hex: 0xFFE8D6), lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(Double(minutes), 30) / 30)
                .stroke(Color(.systemOrange), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: minutes)
            VStack(spacing: 0) {
                Text("\(minutes)").font(.system(size: 40, weight: .bold)).contentTransition(.numericText())
                Text("phút / ngày").font(.footnote).foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(width: 132, height: 132)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mục tiêu \(minutes) phút mỗi ngày")
    }
}

// MARK: - Nhắc học

struct ReminderSettingsView: View {
    let store: LearningSettingsStore

    @State private var draft = LearningSettings.default.reminder
    @State private var didLoad = false
    @State private var permission: NotificationPermission = .notDetermined
    @Environment(\.openURL) private var openURL

    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: draft.time.hour, minute: draft.time.minute, second: 0, of: Date()
                ) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft.time = ReminderTime(hour: parts.hour ?? 20, minute: parts.minute ?? 0)
            }
        )
    }

    private var daysSummary: String {
        if draft.days.count == 7 { return "Nhắc tất cả các ngày trong tuần." }
        if draft.days.isEmpty { return "Vui lòng chọn ít nhất 1 ngày nhắc học." }
        return "Nhắc vào " + draft.days.sorted().map(\.title).joined(separator: ", ") + "."
    }

    private var canSave: Bool {
        draft != store.settings.reminder && !(draft.enabled && draft.days.isEmpty)
    }

    var body: some View {
        SettingsScaffold(title: "Nhắc học", saveTitle: "Lưu", canSave: canSave) {
            if draft.enabled, permission == .notDetermined {
                permission = await store.requestNotificationPermission() ? .allowed : .denied
            }
            var updated = store.settings
            updated.reminder = draft
            try await store.save(updated)
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                GroupedCard {
                    HStack(spacing: 14) {
                        IconTile(systemImage: "bell.fill", tint: Color(.systemRed))
                        Toggle("Nhắc học mỗi ngày", isOn: $draft.enabled.animation(.snappy))
                            .tint(AppColor.success)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                }

                if draft.enabled {
                    if permission == .denied { permissionBanner }

                    VStack(alignment: .leading, spacing: 8) {
                        FormSectionTitle("Giờ nhắc")
                        DatePicker("Giờ nhắc", selection: time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .clipped()
                            .background(AppColor.field, in: RoundedRectangle(cornerRadius: AppMetrics.groupedCardRadius, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FormSectionTitle("Lặp lại")
                        HStack(spacing: 6) {
                            ForEach(Weekday.allCases, id: \.self) { day in
                                let isOn = draft.days.contains(day)
                                Button {
                                    if isOn { draft.days.remove(day) } else { draft.days.insert(day) }
                                } label: {
                                    Text(day.shortTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(isOn ? .white : AppColor.textPrimary)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(isOn ? AppColor.brand : AppColor.field, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(day.title)
                                .accessibilityAddTraits(isOn ? [.isSelected] : [])
                            }
                        }
                        Text(daysSummary)
                            .font(.footnote)
                            .foregroundStyle(draft.days.isEmpty ? AppColor.danger : AppColor.textSecondary)
                            .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        GroupedCard {
                            HStack(spacing: 14) {
                                IconTile(systemImage: "checkmark", tint: Color(.systemGreen))
                                Toggle("Bỏ qua nếu đã học xong", isOn: $draft.skipIfGoalMet)
                                    .tint(AppColor.success)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                        }
                        Text("Không nhắc vào hôm bạn đã đạt mục tiêu \(store.settings.dailyGoalMinutes) phút.")
                            .font(.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                            .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FormSectionTitle("Xem trước")
                        NotificationPreview(
                            time: draft.time.string,
                            message: "Dành \(store.settings.dailyGoalMinutes) phút học tiếng Trung để giữ chuỗi ngày học nhé."
                        )
                    }
                } else {
                    Text("Bật để TingTing nhắc bạn học đúng giờ mỗi ngày.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.horizontal, 20)
                }
            }
        }
        .task {
            if !didLoad {
                didLoad = true
                draft = store.settings.reminder
            }
            permission = await store.notificationPermission()
        }
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(Color(.systemOrange))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Thông báo đang tắt cho TingTing. Bật trong Cài đặt để nhận nhắc học.")
                    .font(.footnote)
                Button("Mở Cài đặt") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.footnote.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.systemOrange).opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct NotificationPreview: View {
    let time: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            BrandLogo(size: 38)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text("TINGTING").font(.footnote.weight(.semibold)).foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(time).font(.footnote).foregroundStyle(AppColor.textSecondary)
                }
                Text("Đến giờ học rồi!").font(.subheadline.weight(.semibold))
                Text(message).font(.subheadline).foregroundStyle(AppColor.textPrimary)
            }
        }
        .padding(12)
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chữ Hán

struct ScriptSettingsView: View {
    let store: LearningSettingsStore

    @State private var script: HanziScript = .simplified
    @State private var pinyinMode: PinyinMode = .always
    @State private var fontSize = LearningSettingsStore.defaultFontSize
    @State private var isPinyinRevealed = false
    @State private var didLoad = false

    private var serverChanged: Bool {
        script != store.settings.script || pinyinMode != store.settings.pinyinMode
    }

    private var canSave: Bool {
        serverChanged || fontSize != store.hanziFontSize
    }

    private var previewHint: String {
        pinyinMode == .onTap ? "Chạm để hiện pinyin" : ""
    }

    private var showsPinyin: Bool {
        switch pinyinMode {
        case .always: return true
        case .onTap: return isPinyinRevealed
        case .never: return false
        }
    }

    var body: some View {
        SettingsScaffold(title: "Chữ Hán", saveTitle: "Lưu", canSave: canSave) {
            // Cỡ chữ chỉ lưu trên máy; kiểu chữ và pinyin lưu lên server.
            store.setHanziFontSize(fontSize)
            guard serverChanged else { return }
            var updated = store.settings
            updated.script = script
            updated.pinyinMode = pinyinMode
            try await store.save(updated)
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                Text("Chọn kiểu chữ dùng trong bài học, từ điển và ôn tập.")
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    ForEach(HanziScript.allCases, id: \.self) { option in
                        Button {
                            script = option
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(option.sample)
                                    .font(.system(size: 34, weight: .medium))
                                    .environment(\.locale, Locale(identifier: option == .simplified ? "zh-Hans" : "zh-Hant"))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(option.title).font(.body.weight(.semibold))
                                    Text(option.region)
                                        .font(.footnote)
                                        .foregroundStyle(AppColor.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppColor.field, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(option == script ? AppColor.brand : .clear, lineWidth: 2)
                            }
                            .overlay(alignment: .topTrailing) {
                                if option == script { SelectionCheck().padding(12) }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(option == script ? [.isSelected] : [])
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    FormSectionTitle("Phiên âm pinyin")
                    Picker("Phiên âm pinyin", selection: $pinyinMode) {
                        ForEach(PinyinMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(pinyinMode.hint)
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 8) {
                    FormSectionTitle("Xem trước")
                    HStack(spacing: 16) {
                        Button {
                            if pinyinMode == .onTap { isPinyinRevealed.toggle() }
                        } label: {
                            // Chữ Hán là mốc căn giữa với cột "học tập"; pinyin nổi phía trên,
                            // ẩn/hiện bằng độ mờ nên không làm xê dịch bố cục.
                            Text(script.sample)
                                .font(.system(size: fontSize, weight: .medium))
                                .frame(minWidth: 96)
                                .overlay(alignment: .top) {
                                    Text(verbatim: "xuéxí")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColor.textSecondary)
                                        .fixedSize()
                                        .alignmentGuide(.top) { $0[.bottom] + 2 }
                                        .opacity(showsPinyin ? 1 : 0)
                                        .animation(.easeOut(duration: 0.15), value: showsPinyin)
                                        .accessibilityHidden(!showsPinyin)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(pinyinMode != .onTap)
                        .accessibilityHint(previewHint)

                        Rectangle().fill(AppColor.separator).frame(width: 0.5)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("học tập").font(.headline)
                            Text("Động từ · HSK 1").font(.footnote).foregroundStyle(AppColor.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    // Chừa chỗ phía trên cho pinyin nổi.
                    .padding(.horizontal, 16)
                    .padding(.top, 34)
                    .padding(.bottom, 16)
                    .background(AppColor.field, in: RoundedRectangle(cornerRadius: AppMetrics.groupedCardRadius, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    FormSectionTitle("Cỡ chữ Hán")
                    HStack(spacing: 12) {
                        Text("字").font(.system(size: 15)).foregroundStyle(AppColor.textSecondary)
                        Slider(value: $fontSize, in: LearningSettingsStore.fontSizeRange, step: 4)
                            .tint(AppColor.brand)
                            .accessibilityLabel("Cỡ chữ Hán")
                        Text("字").font(.system(size: 24)).foregroundStyle(AppColor.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(AppColor.field, in: RoundedRectangle(cornerRadius: AppMetrics.groupedCardRadius, style: .continuous))
                    Text("Chỉ áp dụng trên máy này.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            script = store.settings.script
            pinyinMode = store.settings.pinyinMode
            fontSize = store.hanziFontSize
        }
        .onChange(of: pinyinMode) { _, _ in isPinyinRevealed = false }
    }
}
