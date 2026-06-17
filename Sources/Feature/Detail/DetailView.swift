import SwiftUI
import Shared

// MARK: - Detail View

public struct DetailView: View {
    @State private var viewModel: DetailViewModel

    public init(viewModel: DetailViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        AsyncContentView(state: viewModel.state, onRetry: {
            Task { await viewModel.loadDetail() }
        }) { item in
            content(item)
        }
        .navigationTitle(AppStrings.Detail.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.state.isLoading == false && viewModel.state.data == nil {
                await viewModel.loadDetail()
            }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private func content(_ item: Item) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // 히어로 이미지 영역
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(AppColor.Brand.primary.gradient)
                    .frame(height: 200)
                    .overlay {
                        Image(appIcon: .fileText)
                            .font(AppTypography.heroIconLarge)
                            .foregroundStyle(AppColor.Text.inverse)
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                // 콘텐츠 영역
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text(item.title)
                        .font(AppTypography.title2)
                        .foregroundStyle(AppColor.Text.primary)

                    Text(item.subtitle)
                        .font(AppTypography.body1Regular)
                        .foregroundStyle(AppColor.Text.secondary)

                    Divider()

                    HStack {
                        Label {
                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        } icon: {
                            Image(appIcon: .clock)
                        }
                        .font(AppTypography.caption1)
                        .foregroundStyle(AppColor.Text.secondary)

                        Spacer()

                        Label {
                            Text(String(format: AppStrings.Detail.id, item.id))
                        } icon: {
                            Image(appIcon: .hash)
                        }
                            .font(AppTypography.caption1)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetailView(viewModel: .mock())
    }
}
