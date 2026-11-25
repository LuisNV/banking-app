import Foundation

/// Dữ liệu mẫu cho Trang chủ khi chưa có API.
/// Khi có API: thêm RemoteDataSource + HomeRepositoryImpl và đổi factory ở `Container+Home.swift`.
final class MockHomeRepository: HomeRepository {
    func dashboard() async throws -> HomeDashboard {
        HomeDashboard(
            streakDays: 7,
            dailyGoal: DailyGoal(studiedMinutes: 10, targetMinutes: 15),
            currentLesson: LessonProgress(
                id: "hsk2-5",
                subtitle: "HSK 2 · Bài 5",
                title: "Đi chợ mua sắm",
                newWordCount: 12,
                dialogueCount: 2,
                symbol: "买",
                progress: 0.6
            ),
            wordOfTheDay: WordOfTheDay(
                hanzi: "学习",
                pinyin: "xuéxí",
                meaning: "học tập",
                detail: "Động từ · học, học hỏi",
                level: "HSK 1"
            )
        )
    }
}
