import UIKit

open class BaseButton: UIButton {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder: NSCoder) { fatalError() }

    open func configure() {}
}

public final class PrimaryButton: BaseButton {
    public override func configure() {
        backgroundColor = DSColor.primary
        setTitleColor(.white, for: .normal)
        titleLabel?.font = DSFont.semibold(size: 16)
        layer.cornerRadius = 12
    }
}
