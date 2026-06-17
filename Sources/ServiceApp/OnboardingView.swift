import SwiftUI
import Shared

// MARK: - Onboarding View

struct OnboardingView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(appIcon: .sparkles)
                .font(AppTypography.heroIconLarge)
                .foregroundStyle(AppColor.Brand.primary)

            VStack(spacing: Theme.Spacing.sm) {
                Text(AppStrings.Onboarding.welcome)
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColor.Text.primary)

                Text(AppStrings.Onboarding.ready)
                    .font(AppTypography.body1Regular)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            Spacer()

            Button {
                withAnimation {
                    appState.completeOnboarding()
                }
            } label: {
                Text(AppStrings.Onboarding.start)
                    .font(AppTypography.button1)
                    .foregroundStyle(AppColor.Text.inverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(AppColor.Brand.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(AppColor.Background.primary)
    }
}

#Preview {
    OnboardingView(appState: AppState())
}
