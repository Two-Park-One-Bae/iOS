import SwiftUI
import Shared

// MARK: - Explore View (Placeholder)

public struct ExploreView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(appIcon: .search)
                .font(AppTypography.heroIcon)
                .foregroundStyle(AppColor.Text.tertiary)

            Text(AppStrings.Explore.title)
                .font(AppTypography.title4)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.Background.primary)
        .navigationTitle(AppStrings.Explore.navigationTitle)
    }
}

#Preview {
    NavigationStack {
        ExploreView()
    }
}
