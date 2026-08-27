//
//  LoginVC.swift
//  AuthFeature
//
//  Created by 바견규 on 8/28/26.
//

import Combine
import UIKit

import DSKit
import Domain
import SnapKit
import Then

/// 로그인 화면 (디자인: DESIGN.pen `aj0kv`).
///
/// **둘러보기·건너뛰기가 없다** — 앱 진입은 로그인 필수다(spec: feature/auth/README.md §로그인 화면).
/// 그래서 뒤로 갈 곳도 없어 네비게이션 바를 숨긴다.
public final class LoginVC: UIViewController {

    // MARK: - Properties

    private let viewModel: LoginViewModel
    private var cancelBag = Set<AnyCancellable>()

    // MARK: - UI

    private let logoView = UIImageView().then {
        $0.image = DSBrandImage.logoMark.uiImage
        $0.contentMode = .scaleAspectFit
    }

    private let appNameLabel = UILabel().then {
        $0.text = "널스메이트"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 30)
        $0.textColor = DSColor.textPrimary
    }

    private let taglineLabel = UILabel().then {
        $0.text = "간호사분들의 더 나은 하루를 위해"
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 15)
        $0.textColor = DSColor.textSecondary
    }

    // 디자인 순서 그대로 — 카카오 · Apple · Google.
    private let providerButtons: [SocialLoginButton] = [
        SocialLoginButton(provider: .kakao),
        SocialLoginButton(provider: .apple),
        SocialLoginButton(provider: .google),
    ]

    private let loadingIndicator = UIActivityIndicatorView(style: .medium).then {
        $0.hidesWhenStopped = true
        $0.color = DSColor.Primary._500
    }

    // MARK: - Init

    public init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = DSColor.Neutral._0
        setLayout()
        bind()
    }

    // MARK: - Setup

    private func setLayout() {
        let brandStack = UIStackView(arrangedSubviews: [appNameLabel, taglineLabel]).then {
            $0.axis = .vertical
            $0.spacing = 6
            $0.alignment = .center
        }

        let buttonStack = UIStackView(arrangedSubviews: providerButtons).then {
            $0.axis = .vertical
            $0.spacing = 10
        }

        [logoView, brandStack, buttonStack, loadingIndicator].forEach(view.addSubview)

        // 버튼 묶음을 하단에 고정하고, 로고·문구는 남는 공간의 가운데에 둔다.
        buttonStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(32)
        }

        brandStack.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview().offset(40)
            $0.trailing.lessThanOrEqualToSuperview().offset(-40)
            // 로고 + 문구 묶음이 상단 여백의 중앙에 오도록 — 디자인의 gap 30 을 로고 아래 간격으로 쓴다.
            $0.centerY.equalTo(view.safeAreaLayoutGuide).offset(-40)
        }

        logoView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(brandStack.snp.top).offset(-30)
            $0.width.equalTo(140)
            $0.height.equalTo(124)
        }

        loadingIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(buttonStack.snp.top).offset(-20)
        }
    }

    private func bind() {
        for button in providerButtons {
            button.addAction(
                UIAction { [weak self] _ in self?.viewModel.signIn(with: button.provider) },
                for: .touchUpInside
            )
        }

        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.providerButtons.forEach { $0.isEnabled = !isLoading }
                isLoading ? self?.loadingIndicator.startAnimating() : self?.loadingIndicator.stopAnimating()
            }
            .store(in: &cancelBag)

        viewModel.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                DSAlertCardView.present(on: self.view, title: "로그인 실패", message: message)
            }
            .store(in: &cancelBag)
    }
}
