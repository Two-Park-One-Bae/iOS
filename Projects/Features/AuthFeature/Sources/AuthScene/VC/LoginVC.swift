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
///
/// 화면의 주인공은 로고가 아니라 헤드라인이다 — 브랜드는 좌상단 락업으로 물러나고,
/// 첫 화면에서 "무엇을 해주는 서비스인지"가 먼저 읽히게 한다.
public final class LoginVC: UIViewController {

    // MARK: - Properties

    private let viewModel: LoginViewModel
    private var cancelBag = Set<AnyCancellable>()

    // MARK: - UI

    private let markView = UIImageView().then {
        $0.image = DSBrandImage.logoMark.uiImage
        $0.contentMode = .scaleAspectFit
    }

    /// 워드마크만 Plus Jakarta Sans 를 쓴다 — 본문·라벨은 한글이 필요해 그대로 Pretendard.
    private let wordmarkLabel = UILabel().then {
        $0.attributedText = NSAttributedString(
            string: "NurseMate",
            attributes: [.kern: -0.7,
                         .font: DSKitFontFamily.PlusJakartaSans.extraBold.font(size: 18),
                         .foregroundColor: DSColor.textPrimary]
        )
    }

    private let headlineLabel = UILabel().then {
        $0.numberOfLines = 0
        // 비율 제약과 '버튼과 최소 40 띄우기'가 부딪히면 스택이 눌려 두 번째 줄이 잘린다.
        // 글자는 절대 줄지 않게 두고, 대신 블록이 위로 밀려 올라가게 한다(작은 화면).
        $0.setContentCompressionResistancePriority(.required, for: .vertical)
        $0.attributedText = LoginVC.attributed(
            "간호사의 하루를\n조금 더 가볍게",
            font: DSKitFontFamily.Pretendard.bold.font(size: 34),
            color: DSColor.textPrimary, kern: -1.4, lineHeight: 1.42
        )
    }

    private let subLabel = UILabel().then {
        $0.numberOfLines = 0
        $0.setContentCompressionResistancePriority(.required, for: .vertical)
        $0.attributedText = LoginVC.attributed(
            "알약 식별부터 처치 타이머까지",
            font: DSKitFontFamily.Pretendard.regular.font(size: 15),
            color: DSColor.textSecondary, lineHeight: 1.6
        )
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
        let lockupStack = UIStackView(arrangedSubviews: [markView, wordmarkLabel]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }

        let copyStack = UIStackView(arrangedSubviews: [headlineLabel, subLabel]).then {
            $0.axis = .vertical
            $0.spacing = 14
            $0.alignment = .fill
        }

        let buttonStack = UIStackView(arrangedSubviews: providerButtons).then {
            $0.axis = .vertical
            $0.spacing = 10
        }

        [lockupStack, copyStack, buttonStack, loadingIndicator].forEach(view.addSubview)

        markView.snp.makeConstraints {
            $0.width.equalTo(27)
            $0.height.equalTo(24)
        }

        // 락업·카피는 화면 높이의 비율로 잡는다 — 시안(390x844)의 세로 비례를 기기 크기와
        // 무관하게 유지한다. 고정 offset 으로 두면 화면이 길어질수록 남는 높이가 한쪽으로만
        // 몰려 시안과 다른 화면이 된다.
        lockupStack.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Layout.side)
            $0.top.equalTo(view.snp.bottom).multipliedBy(Layout.lockupTopRatio).priority(.high)
            // 노치가 큰 기기에서 비율값이 상태바를 파고들지 않게 하한을 둔다.
            $0.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(12)
        }

        buttonStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Layout.side)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(32)
        }

        copyStack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Layout.side)
            $0.top.equalTo(view.snp.bottom).multipliedBy(Layout.copyTopRatio).priority(.high)
            // 작은 화면에서는 비율을 포기하고 버튼과 붙지 않는 쪽을 택한다.
            $0.bottom.lessThanOrEqualTo(buttonStack.snp.top).offset(-Layout.minCopyToButtons)
        }

        loadingIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(buttonStack.snp.top).offset(-20)
        }
    }

    /// 디자인(390x844)의 세로 좌표를 화면 높이 대비 비율로 옮긴 값.
    private enum Layout {
        static let side: CGFloat = 24
        static let lockupTopRatio: CGFloat = 74.0 / 844.0
        static let copyTopRatio: CGFloat = 392.0 / 844.0
        static let minCopyToButtons: CGFloat = 40
    }

    private static func attributed(_ text: String, font: UIFont, color: UIColor,
                                   kern: CGFloat = 0, lineHeight: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = font.pointSize * lineHeight
        paragraph.maximumLineHeight = font.pointSize * lineHeight
        return NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .kern: kern, .paragraphStyle: paragraph,
        ])
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
