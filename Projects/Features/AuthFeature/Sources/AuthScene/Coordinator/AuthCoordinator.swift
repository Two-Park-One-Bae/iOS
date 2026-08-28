//
//  AuthCoordinator.swift
//  AuthFeature
//
//  Created by 바견규 on 8/28/26.
//

import UIKit

import BaseFeatureDependency
import DSKit
import Domain

/// 인증 흐름 — 로그인 → (필요하면) 동의 온보딩 → 홈.
///
/// 세션 복원 결과가 `.consent` 면 로그인을 건너뛰고 동의부터 띄운다. 그래도 **로그인 화면을 밑에 깔아둔다** —
/// 동의를 취소하면 로그아웃되어 곧바로 로그인으로 돌아가야 하기 때문이다.
public final class AuthCoordinator: BaseCoordinator {

    private let startRoute: AuthRoute
    private let onFinished: () -> Void

    public init(
        navigationController: UINavigationController,
        startAt startRoute: AuthRoute,
        onFinished: @escaping () -> Void
    ) {
        self.startRoute = startRoute
        self.onFinished = onFinished
        super.init(navigationController: navigationController)
    }

    public override func start() {
        let viewModel = LoginViewModel()
        viewModel.onSignedIn = { [weak self] route in self?.handle(route) }

        let loginVC = LoginVC(viewModel: viewModel)
        navigationController.setViewControllers([loginVC], animated: false)
        navigationController.setNavigationBarHidden(true, animated: false)

        if startRoute == .consent {
            // 로그인 화면이 화면에 올라온 뒤 present 해야 시트가 제대로 붙는다.
            DispatchQueue.main.async { [weak self] in self?.presentConsent() }
        }
    }

    // MARK: - Private

    private func handle(_ route: AuthRoute) {
        switch route {
        case .home:
            onFinished()
        case .consent:
            presentConsent()
        case .login:
            // 로그인 직후에 다시 로그인으로 돌아오는 경로는 없다 — 왔다면 화면을 그대로 둔다.
            break
        }
    }

    private func presentConsent() {
        let viewModel = ConsentViewModel()
        viewModel.onCompleted = { [weak self] in
            self?.navigationController.dismiss(animated: true) { self?.onFinished() }
        }
        viewModel.onCancelled = { [weak self] in
            // 로그아웃까지 끝난 상태 — 시트만 닫으면 밑의 로그인 화면이 그대로 드러난다.
            self?.navigationController.dismiss(animated: true)
        }

        let consentVC = ConsentOnboardingVC(viewModel: viewModel)
        if let sheet = consentVC.sheetPresentationController {
            // 내용 높이에 맞춘 시트. 항목 수가 늘어도 잘리지 않도록 medium 을 함께 둔다.
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = DSRadius.xl
        }
        navigationController.present(consentVC, animated: true)
    }
}
