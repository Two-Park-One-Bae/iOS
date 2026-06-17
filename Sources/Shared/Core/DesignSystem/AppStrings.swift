import SwiftUI

// MARK: - App Strings

/// 로컬라이즈된 문자열에 대한 타입-세이프 접근을 제공한다.
///
/// 새 문자열 추가 절차:
///   1. Sources/Shared/Resources/Localizable.xcstrings 에 키-값 추가
///   2. 아래 enum에 해당 키에 대응하는 static property 추가
///   3. 코드에서 AppStrings.Tab.home 등으로 사용
///
/// 키 이름 규칙: {화면}.{용도} (예: onboarding.welcome)

public enum AppStrings {
    // MARK: - Tab
    public enum Tab {
        public static var home: String {
            String(localized: "tab.home", bundle: .module)
        }

        public static var explore: String {
            String(localized: "tab.explore", bundle: .module)
        }

        public static var settings: String {
            String(localized: "tab.settings", bundle: .module)
        }
    }

    // MARK: - Home
    public enum Home {
        public static var navigationTitle: String {
            String(localized: "home.navigationTitle", bundle: .module)
        }
    }

    // MARK: - Explore
    public enum Explore {
        public static var title: String {
            String(localized: "explore.title", bundle: .module)
        }

        public static var navigationTitle: String {
            String(localized: "explore.navigationTitle", bundle: .module)
        }
    }

    // MARK: - Settings
    public enum Settings {
        public static var title: String {
            String(localized: "settings.title", bundle: .module)
        }

        public static var navigationTitle: String {
            String(localized: "settings.navigationTitle", bundle: .module)
        }
    }

    // MARK: - Detail
    public enum Detail {
        public static var navigationTitle: String {
            String(localized: "detail.navigationTitle", bundle: .module)
        }

        /// ID 라벨 포맷. `String(format: AppStrings.Detail.id, value)`로 사용.
        public static var id: String {
            String(localized: "detail.id", bundle: .module)
        }
    }

    // MARK: - Onboarding
    public enum Onboarding {
        public static var welcome: String {
            String(localized: "onboarding.welcome", bundle: .module)
        }

        public static var ready: String {
            String(localized: "onboarding.ready", bundle: .module)
        }

        public static var start: String {
            String(localized: "onboarding.start", bundle: .module)
        }
    }

    // MARK: - Auth
    public enum Auth {
        public static var required: String {
            String(localized: "auth.required", bundle: .module)
        }
    }

    // MARK: - Maintenance
    public enum Maintenance {
        public static var title: String {
            String(localized: "maintenance.title", bundle: .module)
        }

        public static var retry: String {
            String(localized: "maintenance.retry", bundle: .module)
        }
    }

    // MARK: - Error
    public enum Error {
        public static var title: String {
            String(localized: "error.title", bundle: .module)
        }

        public static var retry: String {
            String(localized: "error.retry", bundle: .module)
        }
    }
}
