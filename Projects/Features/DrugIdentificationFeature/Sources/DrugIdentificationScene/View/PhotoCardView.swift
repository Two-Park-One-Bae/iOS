import UIKit
import SnapKit
import Then
import DSKit

// 촬영 사진을 담는 유리 카드 (④ 로딩 / ⑤ 결과 / ⑥ 결과없음 공용, V2.1.0)
// 300x300 정방형 사진(r14) + 8pt 패딩, 면 glassCard(r20)
final class PhotoCardView: UIView {

    let photoImageView = UIImageView().then {
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
        $0.layer.cornerRadius = 14
    }

    // bbox 오버레이 등을 얹기 위한 사진 위 컨테이너
    let photoContainer = UIView().then {
        $0.clipsToBounds = true
        $0.layer.cornerRadius = 14
    }

    init(photoSize: CGFloat = 300) {
        super.init(frame: .zero)
        setup(photoSize: photoSize)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(photoSize: CGFloat) {
        let surface = DSSurfaceView(spec: .glassCard)
        surface.frame = bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(surface)

        photoContainer.addSubview(photoImageView)
        addSubview(photoContainer)

        photoContainer.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(8)
            $0.width.height.equalTo(photoSize)
        }
        photoImageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func setImage(_ image: UIImage?) {
        photoImageView.image = image
    }
}
