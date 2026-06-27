import UIKit

open class BaseButton: UIButton {

    var config = UIButton.Configuration.plain()
    var title = AttributedString("")

    public init(title: String = "") {
        super.init(frame: .zero)
        configure(title: title)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func configure(title: String) {}
}


// MARK: - Methods

extension BaseButton {
    /// 버튼의 enable 여부 설정
    @discardableResult
    public func setEnabled(_ isEnabled: Bool) -> Self {
        self.isEnabled = isEnabled
        return self
    }

    /// 버튼의 text 설정
    @discardableResult
    public func setTitle(_ title: String) -> Self {
        self.title = AttributedString(title)
        return self
    }

    /// content의 edge 변경
    @discardableResult
    public func changeInset(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) -> Self {
        config.contentInsets = NSDirectionalEdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        self.configuration = config
        return self
    }

    /// 버튼의 cornerRadius 변경
    @discardableResult
    public func changeCornerRadius(radius: Double) -> Self {
        config.background.cornerRadius = radius
        self.configuration = config
        return self
    }

}
