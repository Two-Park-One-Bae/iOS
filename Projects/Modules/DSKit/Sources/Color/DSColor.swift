import UIKit

public enum DSColor {

    // MARK: - Semantic (Light/Dark 자동 전환)

    public static let bgApp         = color("BgApp")
    public static let surface       = color("Surface")
    public static let textPrimary   = color("TextPrimary")
    public static let textSecondary = color("TextSecondary")
    public static let textTertiary  = color("TextTertiary")
    public static let border        = color("Border")

    // MARK: - Primary

    public enum Primary {
        public static let _50  = color("Primary50")
        public static let _100 = color("Primary100")
        public static let _300 = color("Primary300")
        public static let _500 = color("Primary500")
        public static let _600 = color("Primary600")
        public static let _700 = color("Primary700")
        public static let _900 = color("Primary900")
    }

    // MARK: - Secondary

    public enum Secondary {
        public static let _50  = color("Secondary50")
        public static let _100 = color("Secondary100")
        public static let _300 = color("Secondary300")
        public static let _500 = color("Secondary500")
        public static let _600 = color("Secondary600")
        public static let _700 = color("Secondary700")
        public static let _900 = color("Secondary900")
    }

    // MARK: - Neutral

    public enum Neutral {
        public static let _0   = color("Neutral0")
        public static let _50  = color("Neutral50")
        public static let _100 = color("Neutral100")
        public static let _200 = color("Neutral200")
        public static let _300 = color("Neutral300")
        public static let _400 = color("Neutral400")
        public static let _500 = color("Neutral500")
        public static let _600 = color("Neutral600")
        public static let _700 = color("Neutral700")
        public static let _900 = color("Neutral900")
    }

    // MARK: - Status

    public enum Success {
        public static let _50  = color("Success50")
        public static let _100 = color("Success100")
        public static let _300 = color("Success300")
        public static let _500 = color("Success500")
        public static let _600 = color("Success600")
        public static let _700 = color("Success700")
        public static let _900 = color("Success900")
    }

    public enum Warning {
        public static let _50  = color("Warning50")
        public static let _100 = color("Warning100")
        public static let _300 = color("Warning300")
        public static let _500 = color("Warning500")
        public static let _600 = color("Warning600")
        public static let _700 = color("Warning700")
        public static let _900 = color("Warning900")
    }

    public enum Error {
        public static let _50  = color("Error50")
        public static let _100 = color("Error100")
        public static let _300 = color("Error300")
        public static let _500 = color("Error500")
        public static let _600 = color("Error600")
        public static let _700 = color("Error700")
        public static let _900 = color("Error900")
    }

    public enum Info {
        public static let _50  = color("Info50")
        public static let _100 = color("Info100")
        public static let _300 = color("Info300")
        public static let _500 = color("Info500")
        public static let _600 = color("Info600")
        public static let _700 = color("Info700")
        public static let _900 = color("Info900")
    }

    // MARK: - Helper (DSColor 내부 정의 짧게 - color("name"))
    private static func color(_ name: String) -> UIColor {
        UIColor(named: name, in: .module, compatibleWith: nil) ?? .systemPink
    }
    // in:.module Color Resource를 어디서 찾을지 (Bundle)
    //// in: .module → DSKit 번들에서 찾음 (Colors.xcassets)
    //// in: .main → 메인 앱 번들에서 찾음
    //// in: nil → in: .main과 동일
    
    //compatibleWith:은 특정 UITraitCollection에 맞는 컬러를 가져올지 지정하는 파라미터.
    //// nil — 보통 이렇게 씀 (시스템이 알아서 Light/Dark 전환)
    //// nil → 현재 디바이스의 trait(다크모드, 접근성 등)에 자동으로 맞춰서 컬러 반환
    
    
   
}
