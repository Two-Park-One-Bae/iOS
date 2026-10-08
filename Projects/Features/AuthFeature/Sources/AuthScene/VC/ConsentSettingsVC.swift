//
//  ConsentSettingsVC.swift
//  AuthFeature
//

import Combine
import SafariServices
import UIKit

import DSKit
import Domain
import SnapKit
import Then

/// 설정 > 약관 및 동의 (NM-548, 디자인: DESIGN.pen 「약관 및 동의 — 변경 없음 · 선택 해제」).
///
/// 동의 온보딩과 같은 행(`[필수]`·`[선택]` · 이름 · `보기`)을 쓰되 `전체 동의` 행은 없다.
/// 필수 항목은 체크된 채 고정, 선택 항목만 바꿀 수 있고 `저장`을 눌러야 반영된다.
/// 설정에 이용약관·개인정보처리방침 링크 행을 따로 두지 않는다 — 여기 `보기`로 확인한다.
public final class ConsentSettingsVC: UIViewController {

    // MARK: - Properties

    private let viewModel: ConsentSettingsViewModel
    private var cancelBag = Set<AnyCancellable>()
    private var itemRows: [ConsentType: ConsentItemRowView] = [:]

    // MARK: - UI

    private let navBar = DSNavBar(title: "약관 및 동의")

    private let card = UIView().then {
        $0.backgroundColor = DSColor.surface
        $0.layer.cornerRadius = 14
    }

    private let itemStack = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 2
    }

    private let saveButton = PrimaryButton(title: "저장")

    // MARK: - Init

    public init(viewModel: ConsentSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DSColor.bgApp
        setLayout()
        bind()
        viewModel.load()
    }

    // MARK: - Setup

    private func setLayout() {
        view.addSubview(navBar)
        navBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        card.addSubview(itemStack)
        itemStack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(6)
            $0.leading.trailing.equalToSuperview().inset(8)
        }

        view.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalTo(navBar.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        // 항목이 오기 전에는 빈 카드가 보이지 않게 숨겨 둔다.
        card.isHidden = true

        view.addSubview(saveButton)
        saveButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            // 디자인은 홈 인디케이터 영역(34)에 바로 붙는다. 인디케이터가 없는 기기에서는 화면 끝에
            // 닿지 않도록 최소 20 을 띄운다 — 둘 중 더 위쪽이 이긴다.
            $0.bottom.equalTo(view.safeAreaLayoutGuide).priority(.high)
            $0.bottom.lessThanOrEqualToSuperview().inset(20)
            $0.height.equalTo(53)
        }
    }

    private func bind() {
        navBar.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        viewModel.definitions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] definitions in self?.rebuildItems(definitions) }
            .store(in: &cancelBag)

        viewModel.checked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] checked in
                self?.itemRows.forEach { type, row in row.setChecked(checked.contains(type)) }
            }
            .store(in: &cancelBag)

        // 두 조건(바뀐 것이 있음 · 저장 중 아님)을 한 곳에서 합친다 — 따로 구독하면 나중에 도착한 쪽이
        // 앞의 판단을 덮어써서 저장 중에도 버튼이 살아난다.
        viewModel.canSave
            .combineLatest(viewModel.isLoading)
            .map { canSave, isLoading in canSave && !isLoading }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in self?.saveButton.isEnabled = isEnabled }
            .store(in: &cancelBag)

        viewModel.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
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
                isLocked: definition.isRequired,
                onToggle: { [weak self] in self?.viewModel.toggle(definition.type) },
                onOpenPolicy: { [weak self] in self?.openPolicy(definition) }
            )
            row.setChecked(viewModel.checked.value.contains(definition.type))
            itemRows[definition.type] = row
            itemStack.addArrangedSubview(row)
        }
        card.isHidden = definitions.isEmpty
    }

    /// 동의 온보딩과 같다 — 웹 게시분을 그대로 띄우고, 못 여는 URL 은 매퍼에서 이미 걸러져 있다.
    private func openPolicy(_ definition: ConsentDefinition) {
        guard let url = definition.policyUrl else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    // MARK: - Actions

    @objc private func saveTapped() {
        viewModel.save()
    }
}
