import SwiftUI
import Shared

// MARK: - Splash View

struct SplashView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(appIcon: .rocket)
                .font(AppTypography.heroIconLarge)
                .foregroundStyle(AppColor.Brand.primary)

            ProgressView()
                .tint(AppColor.Brand.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.Background.primary)
    }
}

#Preview {
    SplashView()
}
