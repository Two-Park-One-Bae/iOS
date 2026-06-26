import UIKit
import SnapKit
import Then
import DSKit
import Domain

final class HomeCell: UITableViewCell {
    static let identifier = "HomeCell"

    private let titleLabel = UILabel().then {
        $0.font = UIFont.MDS.title.font
        $0.textColor = DSColor.textPrimary
    }

    private let descriptionLabel = UILabel().then {
        $0.font = UIFont.MDS.body.font
        $0.textColor = DSColor.textSecondary
        $0.numberOfLines = 2
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with entity: HomeEntity) {
        titleLabel.text = entity.title
        descriptionLabel.text = entity.description
    }

    private func setLayout() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)

        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(16)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        descriptionLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalToSuperview().inset(16)
        }
    }
}
