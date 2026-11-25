import SwiftUI

private enum HomeCardStyle {
    static let radius: CGFloat = 22
}

/// Thẻ số liệu nhỏ: biểu tượng tròn + giá trị + nhãn.
struct HomeStatCard<Icon: View>: View {
    let value: String
    let label: String
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(spacing: 12) {
            icon.frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppColor.field, in: RoundedRectangle(cornerRadius: HomeCardStyle.radius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Biểu tượng ngọn lửa cho chuỗi ngày học.
struct StreakIcon: View {
    var body: some View {
        Image(systemName: "flame")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color(hex: 0xC93400))
            .frame(width: 38, height: 38)
            .background(Circle().fill(Color(hex: 0xFFE8D6)))
            .accessibilityHidden(true)
    }
}

/// Vòng tiến độ mục tiêu hằng ngày.
struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(Color(.systemGray4), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(AppColor.success, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }
}

/// Thẻ "Học tiếp" bài đang học dở, nền màu thương hiệu.
struct ContinueLessonCard: View {
    let lesson: LessonProgress
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.subtitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(lesson.title)
                    .font(.title2.bold())
                Text("\(lesson.newWordCount) từ mới · \(lesson.dialogueCount) đoạn hội thoại")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: lesson.progress)
                        .progressViewStyle(LessonProgressStyle())
                    Text("Hoàn thành \(Int((lesson.progress * 100).rounded()))%")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .accessibilityElement(children: .combine)

                Button(action: onContinue) {
                    Label("Học tiếp", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(AppColor.brandDark)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Mở bài \(lesson.title)")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.brand)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: AppColor.brand.opacity(0.25), radius: 14, y: 10)
    }
}

private struct LessonProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(.white.opacity(0.3))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: proxy.size.width * (configuration.fractionCompleted ?? 0))
                }
        }
        .frame(height: 6)
    }
}

/// Thẻ "Từ của ngày".
struct WordOfTheDayCard: View {
    let word: WordOfTheDay
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Từ của ngày", systemImage: "star.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.brand)
                    .labelStyle(CompactLabelStyle())
                Spacer()
                Text(word.level)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Capsule().fill(Color(.systemGray5)))
            }

            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(word.pinyin)
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                    Text(word.hanzi)
                        .font(.system(size: 28, weight: .medium))
                }
                .frame(minWidth: 64)
                .accessibilityElement(children: .combine)

                Rectangle()
                    .fill(AppColor.separator)
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 2) {
                    Text(word.meaning)
                        .font(.headline)
                    Text(word.detail)
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onPlay) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(AppColor.brand))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Nghe phát âm \(word.pinyin)")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .background(AppColor.field, in: RoundedRectangle(cornerRadius: HomeCardStyle.radius, style: .continuous))
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.caption)
            configuration.title
        }
    }
}
