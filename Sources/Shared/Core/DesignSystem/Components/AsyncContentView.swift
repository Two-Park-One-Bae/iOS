import SwiftUI

/// 로딩/에러/성공 상태를 자동으로 처리하는 제네릭 뷰 래퍼
public struct AsyncContentView<T, Content: View>: View {
    let state: ViewState<T>
    let onRetry: () -> Void
    @ViewBuilder let content: (T) -> Content

    public init(
        state: ViewState<T>,
        onRetry: @escaping () -> Void,
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.state = state
        self.onRetry = onRetry
        self.content = content
    }

    public var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .success(let data):
            content(data)

        case .failure(let error):
            ErrorView(
                message: error.localizedDescription,
                onRetry: onRetry
            )
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.Status.error)

            Text(AppStrings.Error.title)
                .font(AppTypography.title4)
                .foregroundStyle(AppColor.Text.primary)

            Text(message)
                .font(AppTypography.body2)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

            Button(action: onRetry) {
                Text(AppStrings.Error.retry)
                    .font(AppTypography.title4)
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 44)
                    .background(AppColor.Brand.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
