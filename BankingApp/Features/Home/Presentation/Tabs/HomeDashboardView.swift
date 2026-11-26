import SwiftUI

/// Tab "Trang chủ": lời chào, chuỗi học, mục tiêu, bài đang học, từ của ngày, công cụ.
struct HomeDashboardView: View {
    let viewModel: HomeViewModel

    private let toolColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)

                    if let dashboard = viewModel.dashboard {
                        stats(dashboard)
                        if let lesson = dashboard.currentLesson {
                            ContinueLessonCard(lesson: lesson) {
                                viewModel.selectedTab = .lessons
                            }
                        }
                        if let word = dashboard.wordOfTheDay {
                            WordOfTheDayCard(word: word) { viewModel.playWordOfTheDay() }
                        }
                    } else if viewModel.isLoadingDashboard {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                    }

                    tools
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeTool.self) { tool in
                UtilityDetailPlaceholderView(item: tool.utilityItem)
                    .navigationTitle(tool.fullTitle)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationDestination(for: String.self) { route in
                if route == Self.allToolsRoute {
                    AllToolsView()
                }
            }
        }
        .task { await viewModel.loadDashboard() }
    }

    private static let allToolsRoute = "allTools"

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.dateText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                Text(viewModel.greeting)
                    .font(.largeTitle.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Button {
                viewModel.selectedTab = .profile
            } label: {
                HomeAvatar(viewModel: viewModel, size: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trang cá nhân")
            .padding(.bottom, 2)
        }
        .accessibilityElement(children: .contain)
    }

    private func stats(_ dashboard: HomeDashboard) -> some View {
        HStack(spacing: 12) {
            HomeStatCard(value: "\(dashboard.streakDays) ngày", label: "Liên tiếp") {
                StreakIcon()
            }
            // Mục tiêu lấy từ cài đặt học của người dùng; số phút đã học lấy từ dashboard.
            let goal = viewModel.dailyGoal ?? dashboard.dailyGoal
            let reached = goal.studiedMinutes >= goal.targetMinutes && goal.targetMinutes > 0
            HomeStatCard(
                value: reached ? "\(goal.studiedMinutes) phút" : "\(goal.studiedMinutes)/\(goal.targetMinutes) phút",
                label: reached ? "Đạt mục tiêu \(goal.targetMinutes)′" : "Mục tiêu hôm nay"
            ) {
                ProgressRing(fraction: goal.fraction)
            }
        }
    }

    private var tools: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Công cụ")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                NavigationLink("Tất cả", value: Self.allToolsRoute)
                    .font(.subheadline)
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)

            LazyVGrid(columns: toolColumns, spacing: 14) {
                ForEach(HomeTool.all) { tool in
                    NavigationLink(value: tool) {
                        HomeToolTile(tool: tool)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Ảnh đại diện: ảnh đã upload, ảnh từ server, hoặc chữ cái đầu của tên.
struct HomeAvatar: View {
    let viewModel: HomeViewModel
    let size: CGFloat

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    @ViewBuilder
    private var content: some View {
        if let data = viewModel.avatarImageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let url = viewModel.avatarURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initials
            }
        } else {
            initials
        }
    }

    @ViewBuilder
    private var initials: some View {
        if viewModel.initials.isEmpty {
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(AppColor.brandDark)
                .frame(width: size, height: size)
                .background(AppColor.brand.opacity(0.12))
        } else {
            Text(viewModel.initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(AppColor.brandDark)
                .frame(width: size, height: size)
                .background(AppColor.brand.opacity(0.12))
        }
    }
}
