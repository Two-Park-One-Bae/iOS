import UIKit

public enum DSFont {
    public static func bold(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .bold)
    }

    public static func semibold(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .semibold)
    }

    public static func medium(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .medium)
    }

    public static func regular(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .regular)
    }
}
