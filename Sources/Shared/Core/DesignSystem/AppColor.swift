import SwiftUI

// MARK: - App Color Palette
// 디자인 토큰 소스: DESIGN.pen (Foundation / Color Palette)
// - Scale: 50–900 원색 스케일 (DESIGN.pen 변수와 1:1)
// - 시맨틱 그룹(Brand/Background/Text/Border/Status/Interactive)은 스케일을 UI 역할에 매핑
// - `*-dark` 변형이 정의된 토큰은 라이트/다크 자동 전환 (Color(light:dark:))

public enum AppColor {

    // MARK: - Raw Color Scales (50–900)

    public enum Scale {
        public enum Primary {
            public static let step50 = Color(hex: "EEF2FF")
            public static let step100 = Color(hex: "E0E7FF")
            public static let step300 = Color(hex: "A5B4FC")
            public static let step500 = Color(hex: "6366F1")
            public static let step600 = Color(hex: "4F46E5")
            public static let step700 = Color(hex: "4338CA")
            public static let step900 = Color(hex: "312E81")
        }

        public enum Secondary {
            public static let step50 = Color(hex: "FEF3C7")
            public static let step100 = Color(hex: "FDE68A")
            public static let step300 = Color(hex: "FCD34D")
            public static let step500 = Color(hex: "F59E0B")
            public static let step600 = Color(hex: "D97706")
            public static let step700 = Color(hex: "B45309")
            public static let step900 = Color(hex: "78350F")
        }

        public enum Neutral {
            public static let step0 = Color(hex: "FFFFFF")
            public static let step50 = Color(hex: "F8FAFC")
            public static let step100 = Color(hex: "F1F5F9")
            public static let step200 = Color(hex: "E2E8F0")
            public static let step300 = Color(hex: "CBD5E1")
            public static let step400 = Color(hex: "94A3B8")
            public static let step500 = Color(hex: "64748B")
            public static let step600 = Color(hex: "475569")
            public static let step700 = Color(hex: "334155")
            public static let step900 = Color(hex: "0F172A")
        }

        public enum Success {
            public static let step50 = Color(hex: "F0FDF4")
            public static let step100 = Color(hex: "DCFCE7")
            public static let step300 = Color(hex: "86EFAC")
            public static let step500 = Color(hex: "22C55E")
            public static let step600 = Color(hex: "16A34A")
            public static let step700 = Color(hex: "15803D")
            public static let step900 = Color(hex: "14532D")
        }

        public enum Warning {
            public static let step50 = Color(hex: "FEF3C7")
            public static let step100 = Color(hex: "FDE68A")
            public static let step300 = Color(hex: "FCD34D")
            public static let step500 = Color(hex: "F59E0B")
            public static let step600 = Color(hex: "D97706")
            public static let step700 = Color(hex: "B45309")
            public static let step900 = Color(hex: "78350F")
        }

        public enum Error {
            public static let step50 = Color(hex: "FEF2F2")
            public static let step100 = Color(hex: "FEE2E2")
            public static let step300 = Color(hex: "FCA5A5")
            public static let step500 = Color(hex: "EF4444")
            public static let step600 = Color(hex: "DC2626")
            public static let step700 = Color(hex: "B91C1C")
            public static let step900 = Color(hex: "7F1D1D")
        }

        public enum Info {
            public static let step50 = Color(hex: "EFF6FF")
            public static let step100 = Color(hex: "DBEAFE")
            public static let step300 = Color(hex: "93C5FD")
            public static let step500 = Color(hex: "3B82F6")
            public static let step600 = Color(hex: "2563EB")
            public static let step700 = Color(hex: "1D4ED8")
            public static let step900 = Color(hex: "1E3A8A")
        }
    }

    // MARK: - Brand
    public enum Brand {
        public static let primary = Scale.Primary.step600       // 인디고 (primary-600)
        public static let primaryLight = Scale.Primary.step300   // 연한 인디고
        public static let primaryDark = Scale.Primary.step700    // 진한 인디고
        public static let secondary = Scale.Secondary.step500    // 앰버 (secondary-500)
        public static let accent = Scale.Primary.step500         // 브랜드 강조 (연한 인디고)
    }

    // MARK: - Background
    public enum Background {
        // bg-app: 라이트 #F8FAFC / 다크 #0F172A
        public static let primary = Color(light: "F8FAFC", dark: "0F172A")
        // surface: 카드·바텀시트. 라이트 #FFFFFF / 다크 #1E293B
        public static let secondary = Color(light: "FFFFFF", dark: "1E293B")
        // 입력필드·구분 영역 (neutral-100)
        public static let tertiary = Scale.Neutral.step100
        // 카드·바텀시트 (surface)
        public static let elevated = Color(light: "FFFFFF", dark: "1E293B")
    }

    // MARK: - Text
    public enum Text {
        // 본문. 라이트 #0F172A / 다크 #F8FAFC
        public static let primary = Color(light: "0F172A", dark: "F8FAFC")
        // 보조. 라이트 #64748B / 다크 #94A3B8
        public static let secondary = Color(light: "64748B", dark: "94A3B8")
        // 플레이스홀더·캡션. 라이트 #94A3B8 / 다크 #64748B
        public static let tertiary = Color(light: "94A3B8", dark: "64748B")
        public static let disabled = Scale.Neutral.step300        // 비활성 텍스트
        public static let inverse = Scale.Neutral.step50          // 어두운 배경 위 텍스트
        public static let link = Scale.Primary.step600            // 링크·인터랙티브
    }

    // MARK: - Border & Divider
    public enum Border {
        // 기본 보더. 라이트 #E2E8F0 / 다크 #334155
        public static let primary = Color(light: "E2E8F0", dark: "334155")
        public static let secondary = Scale.Neutral.step100       // 연한 보더
        public static let focus = Scale.Primary.step600           // 포커스 보더
    }

    // MARK: - Status
    public enum Status {
        public static let success = Scale.Success.step500
        public static let successBackground = Scale.Success.step50
        public static let warning = Scale.Warning.step500
        public static let warningBackground = Scale.Warning.step50
        public static let error = Scale.Error.step500
        public static let errorBackground = Scale.Error.step50
        public static let info = Scale.Info.step500
        public static let infoBackground = Scale.Info.step50
    }

    // MARK: - Interactive
    public enum Interactive {
        public static let pressed = Color(hex: "000000").opacity(0.05)   // 눌림 오버레이
        public static let disabled = Scale.Neutral.step400               // 비활성 버튼
        public static let disabledBackground = Scale.Neutral.step100     // 비활성 배경
        public static let overlay = Color(hex: "000000").opacity(0.4)    // 모달 오버레이
    }
}
