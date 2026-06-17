import SwiftUI
import Shared

// MARK: - Auth View (Placeholder)

struct AuthView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(appIcon: .userCircle)
                .font(AppTypography.heroIcon)
                .foregroundStyle(AppColor.Text.tertiary)

            Text(AppStrings.Auth.required)
                .font(AppTypography.title4)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.Background.primary)
    }
}

#Preview {
    AuthView()
}
