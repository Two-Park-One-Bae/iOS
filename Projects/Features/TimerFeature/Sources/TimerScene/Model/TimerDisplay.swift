import UIKit
import DSKit
import Domain

// MARK: - 분류 표시 (투약 / 처치 / 검사)

extension TimerCategory {
    var displayName: String {
        switch self {
        case .medication:  return "투약"
        case .treatment:   return "처치"
        case .examination: return "검사"
        }
    }

    // 카드 태그 칩 색 (C1 디자인)
    var tagBackground: UIColor {
        switch self {
        case .medication:  return DSColor.Primary._50    // #F0F9FF
        case .treatment:   return DSColor.Secondary._50  // #F0FDFA
        case .examination: return DSColor.Info._50       // #EFF6FF
        }
    }

    var tagText: UIColor {
        switch self {
        case .medication:  return DSColor.Primary._700   // #0369A1
        case .treatment:   return DSColor.Secondary._700 // #0F766E
        case .examination: return DSColor.Info._700      // #1D4ED8
        }
    }
}

// MARK: - 시간 포맷

enum TimerFormat {

    /// 전체 시간 라벨: 900→"15분", 7200→"2시간", 5400→"1시간 30분", 90→"1분 30초"
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)시간") }
        if m > 0 { parts.append("\(m)분") }
        if s > 0 { parts.append("\(s)초") }
        return parts.isEmpty ? "0초" : parts.joined(separator: " ")
    }

    /// 카운트다운: 754→"12:34", 4360→"1:12:40"
    static func countdown(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
