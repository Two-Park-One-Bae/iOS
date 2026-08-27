//
//  SocialLoginButton.swift
//  AuthFeature
//
//  Created by 바견규 on 8/28/26.
//

import UIKit

import DSKit
import Domain
import SnapKit
import Then

/// 공급자별 로그인 버튼 (디자인: DESIGN.pen `aj0kv`).
///
/// 세 공급자 모두 높이 54 · r12 로 같고 색·로고만 다르다. 카카오·구글은 브랜드 가이드가 정한 색이라
/// 디자인 토큰이 아니라 **고정 색상**을 쓴다 — 다크모드에서도 바뀌면 안 된다.
final class SocialLoginButton: UIControl {

    private enum Palette {
        static let kakaoYellow = UIColor(red: 0xFE / 255, green: 0xE5 / 255, blue: 0x00 / 255, alpha: 1)
        static let googleBorder = UIColor(red: 0xDA / 255, green: 0xDC / 255, blue: 0xE0 / 255, alpha: 1)
        static let googleLabel = UIColor(red: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255, alpha: 1)
    }

    let provider: AuthProvider

    private let markView = UIImageView().then {
        $0.contentMode = .scaleAspectFit
    }

    private let titleLabel = UILabel().then {
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
    }

    init(provider: AuthProvider) {
        self.provider = provider
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.85 : 1 }
    }

    override var isEnabled: Bool {
        // 로그인 진행 중에는 세 버튼이 모두 잠긴다 — 두 공급자로 동시에 로그인하는 경로를 막는다.
        didSet { alpha = isEnabled ? 1 : 0.5 }
    }

    private func setup() {
        layer.cornerRadius = DSRadius.md
        snp.makeConstraints { $0.height.equalTo(54) }

        switch provider {
        case .kakao:
            backgroundColor = Palette.kakaoYellow
            markView.image = DSBrandImage.kakao.uiImage.withRenderingMode(.alwaysTemplate)
            markView.tintColor = .black
            titleLabel.text = "카카오 로그인"
            titleLabel.textColor = .black
        case .apple:
            backgroundColor = .black
            markView.image = DSBrandImage.appleLogo(pointSize: 19)
            markView.tintColor = .white
            titleLabel.text = "Apple로 로그인"
            titleLabel.textColor = .white
        case .google:
            backgroundColor = .white
            layer.borderWidth = 1
            layer.borderColor = Palette.googleBorder.cgColor
            markView.image = DSBrandImage.google.uiImage
            titleLabel.text = "Google로 계속하기"
            titleLabel.textColor = Palette.googleLabel
        }

        let stack = UIStackView(arrangedSubviews: [markView, titleLabel]).then {
            $0.axis = .horizontal
            $0.spacing = 10
            $0.alignment = .center
            // 하위 뷰가 터치를 먹으면 UIControl 의 touchUpInside 가 오지 않는다.
            $0.isUserInteractionEnabled = false
        }

        addSubview(stack)
        stack.snp.makeConstraints { $0.center.equalToSuperview() }
        markView.snp.makeConstraints { $0.width.height.equalTo(22) }
    }
}
