import Foundation

/// Dữ liệu tổng quan hiển thị ở Trang chủ.
struct HomeDashboard: Equatable {
    /// Số ngày học liên tiếp.
    let streakDays: Int
    let dailyGoal: DailyGoal
    let currentLesson: LessonProgress?
    let wordOfTheDay: WordOfTheDay?
}

struct DailyGoal: Equatable {
    let studiedMinutes: Int
    let targetMinutes: Int

    /// Tỉ lệ hoàn thành, kẹp trong 0...1.
    var fraction: Double {
        guard targetMinutes > 0 else { return 0 }
        return min(max(Double(studiedMinutes) / Double(targetMinutes), 0), 1)
    }
}

/// Bài học đang học dở.
struct LessonProgress: Equatable, Identifiable {
    let id: String
    /// Vd. "HSK 2 · Bài 5".
    let subtitle: String
    let title: String
    let newWordCount: Int
    let dialogueCount: Int
    /// Chữ Hán trang trí trên thẻ bài học.
    let symbol: String
    /// 0...1
    let progress: Double
}

struct WordOfTheDay: Equatable {
    let hanzi: String
    let pinyin: String
    let meaning: String
    /// Vd. "Động từ · học, học hỏi".
    let detail: String
    /// Vd. "HSK 1".
    let level: String
}
