//
//  ConsentOnboardingVC.swift
//  AuthFeature
//
//  Created by 바견규 on 8/28/26.
//

import Combine
import SafariServices
import UIKit

import DSKit
import Domain
import SnapKit
import Then

/// 약관 동의 온보딩 (디자인: DESIGN.pen `b6vnhN` · 미완료 상태 `EkP5R`).
///
/// 로그인 화면 위에 바텀시트로 뜬다. **스와이프로 닫을 수 없다** — 화면에서 가능한 행동은
/// '동의하고 계속'과 '취소(→ 로그아웃)' 둘뿐이고, 동의 없이 홈으로 가는 경로는 없다
/// (spec: feature/auth/README.md §동의 온보딩).
public final class ConsentOnboardingVC: UIViewController {

    // MARK: - Properties

    private let viewModel: ConsentViewModel
    private var cancelBag = Set<AnyCancellable>()
    private var itemRows: [ConsentType: ConsentItemRowView] = [:]

    // MARK: - UI

    private let titleLabel = UILabel().then {
        $0.text = "약관 동의"
        $0.font = DSKitFontFamily.Pretendard.bold.font(size: 22)
        $0.textColor = DSColor.textPrimary
        $0.textAlignment = .center
    }

    private let subtitleLabel = UILabel().then {
        $0.text = "널스메이트 이용을 위해 아래 약관 동의가 필요해요"
        $0.font = DSKitFontFamily.Pretendard.regular.font(size: 13)
        $0.textColor = DSColor.textSecondary
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private let agreeAllCheckbox = DSCheckbox(size: .large)

    private let agreeAllLabel = UILabel().then {
        $0.text = "전체 동의"
        $0.font = DSKitFontFamily.Pretendard.semiBold.font(size: 16)
        $0.textColor = DSColor.textPrimary
    }

    private let dividerView = UIView().then {
        $0.backgroundColor = DSColor.border
    }

    private let itemStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 2
    }

    /// 시트 높이를 이 스택의 실제 높이로 잡는다 — 아래 여백이 남지 않게.
    private let rootStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 24
        $0.alignment = .fill
    }

    private let agreeButton = PrimaryButton(title: "동의하고 계속")

    private let cancelButton = UIButton(type: .system).then {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = DSColor.Primary._600
        var title = AttributedString("취소")
        title.font = DSKitFontFamily.Pretendard.semiBold.font(size: 15)
        config.attributedTitle = title
        $0.configuration = config
    }

    // MARK: - Init

    public init(viewModel: ConsentViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        // 스와이프 다운으로 내려가면 "로그인됐지만 미동의" 상태가 화면에 남는다.
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DSColor.surface
        setLayout()
        bind()
        viewModel.load()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // rootStack 은 위에서 고정이라 시트 높이와 무관하게 자기 높이가 정해진다 —
        // 그래서 한 번 재고 detent 를 갱신하면 그대로 수렴한다.
        let height = rootStack.frame.maxY + bottomPadding
        guard height > 0, abs(height - measuredHeight) > 0.5 else { return }
        measuredHeight = height
        applyContentDetent()
    }

    // MARK: - Setup

    private func setLayout() {
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel]).then {
            $0.axis = .vertical
            $0.spacing = 6
            $0.alignment = .fill
        }

        let agreeAllStack = UIStackView(arrangedSubviews: [agreeAllCheckbox, agreeAllLabel, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 12
            $0.alignment = .center
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 16, left: 4, bottom: 16, right: 4)
            $0.isUserInteractionEnabled = true
        }
        agreeAllStack.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(agreeAllTapped)))

        let consentStack = UIStackView(arrangedSubviews: [agreeAllStack, dividerView, itemStack]).then {
            $0.axis = .vertical
            $0.spacing = 0
            $0.alignment = .fill
        }
        dividerView.snp.makeConstraints { $0.height.equalTo(1) }

        agreeButton.snp.makeConstraints { $0.height.equalTo(52) }
        cancelButton.snp.makeConstraints { $0.height.equalTo(44) }

        let buttonStack = UIStackView(arrangedSubviews: [agreeButton, cancelButton]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .fill
        }

        [textStack, consentStack, buttonStack].forEach(rootStack.addArrangedSubview)

        view.addSubview(rootStack)
        rootStack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Layout.top)
            $0.leading.trailing.equalToSuperview().inset(Layout.side)
        }
    }

    // MARK: - Sheet height

    private enum Layout {
        static let top: CGFloat = 28
        static let side: CGFloat = 24
        /// 디자인의 아래 여백. 홈 인디케이터가 있으면 그쪽이 더 크므로 둘 중 큰 값을 쓴다
        /// (더하면 취소 아래가 두 배로 벌어진다).
        static let bottom: CGFloat = 28
    }

    /// detent 값에는 시스템이 하단 세이프에어리어를 **따로 더한다**.
    /// 그래서 홈 인디케이터가 있는 기기에서는 여기서 더 얹을 게 없다 —
    /// 더하면 취소 아래가 디자인의 두 배로 벌어진다.
    private var bottomPadding: CGFloat { max(0, Layout.bottom - view.safeAreaInsets.bottom) }

    /// 배치가 끝난 뒤 잰 실제 높이. 추정값(systemLayoutSizeFitting)은 버튼·라벨에서 몇 십 pt 씩 어긋난다.
    private var measuredHeight: CGFloat = 0

    /// 시트를 내용 높이에 딱 맞춘다.
    ///
    /// `.medium()` 은 화면의 절반을 고정으로 잡아 '취소' 아래가 크게 비었다.
    /// 항목 수·글자 크기에 따라 높이가 달라지므로, 약관이 도착해 화면을 다시 그린 뒤에도
    /// 한 번 더 계산한다(`invalidateDetents`).
    private func applyContentDetent() {
        guard let sheet = sheetPresentationController else { return }
        sheet.detents = [.custom(identifier: .consentContent) { [weak self] context in
            guard let self else { return nil }
            return min(self.contentHeight(), context.maximumDetentValue)
        }]
        sheet.selectedDetentIdentifier = .consentContent
        sheet.animateChanges { sheet.invalidateDetents() }
    }

    private func contentHeight() -> CGFloat {
        if measuredHeight > 0 { return measuredHeight }

        // 배치 전(첫 detent 계산)에는 추정으로 시작하고, 배치가 끝나면 실측으로 교체한다.
        let width = view.bounds.width > 0
            ? view.bounds.width
            : (presentingViewController?.view.bounds.width ?? 390)
        let fitted = rootStack.systemLayoutSizeFitting(
            CGSize(width: width - Layout.side * 2, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        return Layout.top + fitted + bottomPadding
    }

    private func bind() {
        agreeButton.addTarget(self, action: #selector(agreeTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        viewModel.definitions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] definitions in self?.rebuildItems(definitions) }
            .store(in: &cancelBag)

        viewModel.checked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] checked in
                guard let self else { return }
                self.itemRows.forEach { type, row in row.setChecked(checked.contains(type)) }
                // '전체 동의'는 스스로 상태를 갖지 않는다 — 항목이 전부 켜졌을 때만 켜진 것으로 보인다.
                let all = Set(self.viewModel.definitions.value.map(\.type))
                self.agreeAllCheckbox.setChecked(!all.isEmpty && checked == all)
            }
            .store(in: &cancelBag)

        // 두 조건(필수 동의 완료 · 저장 중 아님)을 한 곳에서 합친다 —
        // 따로 구독하면 나중에 도착한 쪽이 앞의 판단을 덮어써서 저장 중에도 버튼이 살아난다.
        viewModel.canProceed
            .combineLatest(viewModel.isLoading)
            .map { canProceed, isLoading in canProceed && !isLoading }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in self?.agreeButton.isEnabled = isEnabled }
            .store(in: &cancelBag)

        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                // 화면 전체를 잠그지 않는다 — 요청이 길어지면 그 위에 뜬 안내 팝업까지 눌리지 않는다.
                // 중복 실행만 막으면 되므로 취소 버튼만 잠근다('동의하고 계속'은 위에서 함께 계산한다).
                self?.cancelButton.isEnabled = !isLoading
            }
            .store(in: &cancelBag)

        viewModel.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                // 다이얼로그와 같은 이유로 시트가 아니라 창에 띄운다.
                DSAlertCardView.present(on: self.view.window ?? self.view, title: "알림", message: message)
            }
            .store(in: &cancelBag)
    }

    private func rebuildItems(_ definitions: [ConsentDefinition]) {
        itemStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        itemRows.removeAll()

        for definition in definitions {
            let row = ConsentItemRowView(
                definition: definition,
                onToggle: { [weak self] in self?.viewModel.toggle(definition.type) },
                onOpenPolicy: { [weak self] in self?.openPolicy(definition) }
            )
            itemRows[definition.type] = row
            itemStack.addArrangedSubview(row)
        }

        applyContentDetent()
    }

    /// 약관 전문은 웹 게시분을 그대로 띄운다 — 앱에 복사해두면 개정 때마다 어긋난다.
    ///
    /// URL 검증은 매퍼(`ConsentDefinitionEntity.toDomain`)에서 끝나 있고, 여기 nil 이면 행이
    /// 이미 '보기'를 감춘 상태다. 그래도 남겨두는 건 `SFSafariViewController` 가 http·https 아닌
    /// URL 에 예외를 던지기 때문 — 이 경로로는 절대 크래시하지 않게 한다.
    private func openPolicy(_ definition: ConsentDefinition) {
        guard let url = definition.policyUrl else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    // MARK: - Actions

    @objc private func agreeAllTapped() {
        viewModel.toggleAll()
    }

    @objc private func agreeTapped() {
        viewModel.agree()
    }

    /// 취소는 곧 로그아웃이라 한 번 되묻는다 (디자인: DESIGN.pen `Kf67G`).
    @objc private func cancelTapped() {
        // 시트가 아니라 창에 띄운다 — 시트에 붙이면 dim 이 시트만 덮는다.
        DSConfirmDialogView.presentOverWindow(
            title: "로그인 화면으로 돌아갈까요?",
            message: "동의하지 않으면 이용이 제한돼요",
            confirmTitle: "로그아웃",
            confirmed: { [weak self] in self?.viewModel.cancelAndSignOut() }
        )
    }
}

private extension UISheetPresentationController.Detent.Identifier {
    static let consentContent = Self("consentContent")
}
