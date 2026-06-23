import UIKit

public enum DSColor {
    public static let primary = UIColor(named: "Primary", in: .module, compatibleWith: nil) ?? .systemBlue
    public static let background = UIColor(named: "Background", in: .module, compatibleWith: nil) ?? .systemBackground
    public static let text = UIColor(named: "Text", in: .module, compatibleWith: nil) ?? .label
    public static let subtext = UIColor(named: "Subtext", in: .module, compatibleWith: nil) ?? .secondaryLabel
    public static let separator = UIColor(named: "Separator", in: .module, compatibleWith: nil) ?? .separator
}
