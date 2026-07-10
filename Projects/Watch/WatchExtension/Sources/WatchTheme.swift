import SwiftUI
import TimerDomain

// 워치 디자인 토큰 — spec/design DESIGN.pen (W1/W2/W3) 색·컴포넌트 매핑.
enum WT {
    static let card = Color(hex: "1C1C1E")
    static let track = Color(hex: "3A3A3C")
    static let accent = Color(hex: "0EA5E9")        // 진행 링·재생
    static let remaining = Color(hex: "7DD3FC")     // 남은 시간(진행 중)
    static let muted = Color(hex: "8E8E93")         // 보조·일시정지
    static let textPrimary = Color(hex: "F8FAFC")
    static let ringingBg = Color(hex: "422006")     // 만료 카드 배경
    static let ringingAccent = Color(hex: "D97706") // 만료 강조·완료 버튼
    static let bell = Color(hex: "F59E0B")
    static let stop = Color(hex: "EF4444")

    // 분류 태그 색 (처치=청록 / 검사=파랑 / 투약=하늘)
    static func category(_ c: TimerCategory) -> Color {
        switch c {
        case .treatment:   return Color(hex: "5EEAD4")
        case .examination: return Color(hex: "93C5FD")
        case .medication:  return Color(hex: "7DD3FC")
        }
    }
}

extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}

// 진행률 링 — 남은 시간 비율만큼 채운다(위에서 시계방향). 일시정지면 가운데 pause.
struct ProgressRing: View {
    var progress: Double          // 0…1 (남은/전체)
    var tint: Color
    var lineWidth: CGFloat = 5
    var paused: Bool = false

    var body: some View {
        ZStack {
            Circle().stroke(WT.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if paused {
                Image(systemName: "pause.fill")
                    .font(.system(size: lineWidth * 2.2))
                    .foregroundStyle(tint)
            }
        }
    }
}

// DSKit lucide 아이콘(워치 애셋에 복사) — 템플릿 렌더 + 틴트.
// Foundation/Icons 의 실제 에셋(ic_play·ic_pause·ic_bell·ic_check·ic_plus·ic_chevron_right).
struct WIcon: View {
    let name: String                  // "ic_play"
    var size: CGFloat = 20
    var color: Color = WT.textPrimary

    var body: some View {
        Image("Icons/\(name)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}

// 시간 포맷 — 폰 TimerFormat 과 동일.
enum WatchFormat {
    static func countdown(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)시간") }
        if m > 0 { parts.append("\(m)분") }
        if s > 0 { parts.append("\(s)초") }
        return parts.isEmpty ? "0초" : parts.joined(separator: " ")
    }
}
