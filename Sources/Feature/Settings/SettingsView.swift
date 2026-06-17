import SwiftUI
import Shared

// MARK: - Settings View (Placeholder)

public struct SettingsView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(appIcon: .settings)
                .font(AppTypography.heroIcon)
                .foregroundStyle(AppColor.Text.tertiary)

            Text(AppStrings.Settings.title)
                .font(AppTypography.title4)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.Background.primary)
        .navigationTitle(AppStrings.Settings.navigationTitle)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
