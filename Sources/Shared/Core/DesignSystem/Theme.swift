import SwiftUI

// MARK: - App Theme

public enum Theme {
    // MARK: - Spacing
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    public enum CornerRadius {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
    }
}

// MARK: - View State

public enum ViewState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var data: T? {
        if case .success(let data) = self { return data }
        return nil
    }
}

extension ViewState: Equatable where T: Equatable {
    public static func == (lhs: ViewState<T>, rhs: ViewState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.success(let a), .success(let b)):
            return a == b
        default:
            return false
        }
    }
}
