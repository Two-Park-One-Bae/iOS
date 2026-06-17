import SwiftUI
import Shared

// MARK: - Main Tab

public enum MainTab: String, CaseIterable {
    case home
    case explore
    case settings

    var title: String {
        switch self {
        case .home: return AppStrings.Tab.home
        case .explore: return AppStrings.Tab.explore
        case .settings: return AppStrings.Tab.settings
        }
    }

    var icon: AppIcon {
        switch self {
        case .home: return .house
        case .explore: return .search
        case .settings: return .settings
        }
    }
}
