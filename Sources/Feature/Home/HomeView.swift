import SwiftUI
import Shared

// MARK: - Home View

public struct HomeView: View {
    private let viewModel: HomeViewModel
    private let router: HomeRouter

    public init(viewModel: HomeViewModel, router: HomeRouter) {
        self.viewModel = viewModel
        self.router = router
    }

    public var body: some View {
        AsyncContentView(state: viewModel.state, onRetry: {
            Task { await viewModel.loadItems() }
        }) { items in
            itemList(items)
        }
        .task {
            if viewModel.state.isLoading == false && viewModel.state.data == nil {
                await viewModel.loadItems()
            }
        }
    }

    // MARK: - Item List
    @ViewBuilder
    private func itemList(_ items: [Item]) -> some View {
        List(items) { item in
            Button {
                router.navigate(to: .detail(itemID: item.id))
            } label: {
                itemRow(item)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .navigationTitle(AppStrings.Home.navigationTitle)
    }

    // MARK: - Item Row
    @ViewBuilder
    private func itemRow(_ item: Item) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(AppColor.Brand.primary.gradient)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(appIcon: .fileText)
                        .foregroundStyle(AppColor.Text.inverse)
                        .font(AppTypography.title3)
                }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(item.title)
                    .font(AppTypography.title4)
                    .foregroundStyle(AppColor.Text.primary)

                Text(item.subtitle)
                    .font(AppTypography.body2)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            Spacer()

            Image(appIcon: .chevronRight)
                .font(AppTypography.caption1)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView(viewModel: .mock(), router: HomeRouter())
    }
}
