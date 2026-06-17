import SwiftUI
import Shared

// MARK: - Maintenance View (Placeholder)

struct MaintenanceView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(appIcon: .wrench)
                .font(AppTypography.heroIcon)
                .foregroundStyle(AppColor.Status.warning)

            VStack(spacing: Theme.Spacing.sm) {
                Text(AppStrings.Maintenance.title)
                    .font(AppTypography.title4)
                    .foregroundStyle(AppColor.Text.primary)

                Text(AppStrings.Maintenance.retry)
                    .font(AppTypography.body2)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.Background.primary)
    }
}

#Preview {
    MaintenanceView()
}
