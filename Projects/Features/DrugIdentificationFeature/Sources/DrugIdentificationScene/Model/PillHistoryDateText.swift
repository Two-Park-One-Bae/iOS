import Foundation

// 식별 기록의 시각 표기 (spec: feature/pill-recognition/README.md §식별 기록).
// 날짜는 기기 시간대로 나눈다 — 알약 탭 목록 · 기록 상세가 같은 규칙을 쓴다.
enum PillHistoryDateText {

    private static var calendar: Calendar { .current }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    /// 목록 날짜 묶음 라벨: `오늘` · `어제` · `10월 7일 (수)` — 올해가 아니면 `2025년 10월 7일 (화)`.
    static func sectionTitle(_ date: Date, now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "오늘" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "어제"
        }
        return dateText(date, now: now)
    }

    /// 목록 한 줄의 시각: `오후 2:14`.
    static func time(_ date: Date) -> String {
        formatter("a h:mm").string(from: date)
    }

    /// 기록 상세 머리: `10월 9일 (금) 오후 2:14` — 올해가 아니면 연도를 붙인다.
    static func detail(_ date: Date, now: Date = Date()) -> String {
        "\(dateText(date, now: now)) \(time(date))"
    }

    private static func dateText(_ date: Date, now: Date) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return formatter(sameYear ? "M월 d일 (E)" : "yyyy년 M월 d일 (E)").string(from: date)
    }
}
