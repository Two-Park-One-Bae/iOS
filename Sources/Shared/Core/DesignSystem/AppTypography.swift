import SwiftUI

// MARK: - App Typography
// 디자인 토큰 소스: DESIGN.pen (Foundation / Typography)
// 앱은 Pretendard만 사용한다.

public enum AppTypography {

    // MARK: - Font Family (DESIGN.pen)
    public enum Family {
        public static let display = "Pretendard"           // Headings · Display
        public static let body = "Pretendard"              // Body · Caption
    }

    // MARK: - Type Scale (DESIGN.pen)

    /// Display · 46 · 700
    public static let display = Font.custom("Pretendard-Bold", size: 46)
    /// Heading 1 · 36 · 700
    public static let heading1 = Font.custom("Pretendard-Bold", size: 36)
    /// Heading 2 · 28 · 600
    public static let heading2 = Font.custom("Pretendard-SemiBold", size: 28)
    /// Heading 3 · 22 · 600
    public static let heading3 = Font.custom("Pretendard-SemiBold", size: 22)
    /// Title · 18 · 600
    public static let title = Font.custom("Pretendard-SemiBold", size: 18)
    /// Body Large · 16 · 400
    public static let bodyLarge = Font.custom("Pretendard-Regular", size: 16)
    /// Body · 14 · 400
    public static let body = Font.custom("Pretendard-Regular", size: 14)
    /// Caption · 12 · 500
    public static let caption = Font.custom("Pretendard-Medium", size: 12)

    // MARK: - Letter Spacing → `.tracking()`
    public enum Tracking {
        public static let display: CGFloat = -1.0
        public static let heading1: CGFloat = -0.5
        public static let heading2: CGFloat = -0.3
        public static let heading3: CGFloat = -0.2
        public static let caption: CGFloat = 0.2
    }

    // MARK: - iOS Tokens (펜 스케일 기반 파생)
    public static let button1 = Font.custom("Pretendard-SemiBold", size: 16)
    public static let button2 = Font.custom("Pretendard-SemiBold", size: 14)
    public static let navTitle = Font.custom("Pretendard-SemiBold", size: 17)
    public static let navLargeTitle = Font.custom("Pretendard-Bold", size: 34)
    public static let tabLabel = Font.custom("Pretendard-Medium", size: 10)
    public static let label1 = Font.custom("Pretendard-SemiBold", size: 14)
    public static let label2 = Font.custom("Pretendard-Medium", size: 12)
    public static let label3 = Font.custom("Pretendard-Medium", size: 11)

    // MARK: - Hero Icon Sizes (SF Symbol 히어로 아이콘, 펜 스케일 파생)
    // 패밀리는 무의미(SF Symbol은 시스템 렌더링)하고 size만 의미. 토큰화로 매직넘버 회피.
    /// Hero Icon · 48
    public static let heroIcon = Font.custom("Pretendard-Regular", size: 48)
    /// Hero Icon Large · 64
    public static let heroIconLarge = Font.custom("Pretendard-Regular", size: 64)

    // MARK: - Legacy Aliases (기존 코드 호환)
    public static let display1 = heading1        // 36 · Bold
    public static let title1 = heading1          // 36 · Bold
    public static let title2 = heading2          // 28 · SemiBold (was 24 · Bold)
    public static let title3 = heading3          // 22 · SemiBold
    public static let title4 = title             // 18 · SemiBold
    public static let body1 = bodyLarge          // 16 · Regular
    public static let body1Regular = bodyLarge   // 16 · Regular
    public static let body2 = body               // 14 · Regular (was Medium)
    public static let body2Regular = body        // 14 · Regular
    public static let caption1 = caption         // 12 · Medium (was Regular)
    public static let caption2 = caption         // 12 · Medium
}
