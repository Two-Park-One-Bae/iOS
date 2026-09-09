//
//  AuthCoordinator.swift
//  AuthFeature
//
//  Created by 바견규 on 8/28/26.
//

import UIKit

import BaseFeatureDependency
import Core
import DSKit
import Domain

/// 인증 흐름 — 로그인 → (필요하면) 동의 온보딩 → 홈.
///
/// 세션 복원 결과가 `.consent` 면 로그인을 건너뛰고 동의부터 띄운다. 그래도 **로그인 화면을 밑에 깔아둔다** —
/// 동의를 취소하면 로그아웃되어 곧바로 로그인으로 돌아가야 하기 때문이다.
public final class AuthCoordinator: BaseCoordinator {

    private let startRoute: AuthRoute
    private let onFinished: () -> Void

    /// 개정 재동의 여부를 읽기 위해서만 쓴다 (`AuthUser.needsReconsent`).
    @Injected private var useCase: AuthUseCase

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

    /*
     동의 온보딩 진입.

     약관이 **개정**되어 다시 묻는 경우에는 시트 앞에 안내를 한 장 세운다. 이미 동의하고 쓰던
     사람에게 같은 화면이 예고 없이 다시 뜨면 앱이 동의를 잃어버린 것으로 읽히기 때문이다.
     최초 가입자는 흐름상 동의가 당연한 단계라 안내 없이 곧장 시트로 간다.

     안내를 띄우는 시점은 **앱을 켤 때**다(spec: feature/auth/README.md §동의 온보딩 "다음 진입 때").
     포그라운드 복귀마다 다시 판정하지 않는다 — 그 시점엔 `restoreSession()` 이 돌지 않으므로
     `user` 값도 바뀌지 않는다.
     */
    private func presentConsent() {
        guard useCase.user.value?.needsReconsent == true else {
            presentConsentSheet()
            return
        }

        DSAlertCardView.presentOverWindow(
            title: "약관이 변경되었어요",
            message: "서비스를 계속 이용하려면 변경된 약관에 다시 동의해 주세요.",
            confirmTitle: "확인"
        ) { [weak self] in
            self?.presentConsentSheet()
        }
    }

    private func presentConsentSheet() {
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
            // 높이(detent)는 내용에 맞춰 화면 쪽에서 잡는다 — 항목 수를 아는 건 저쪽뿐이다.
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = DSRadius.xl
        }
        navigationController.present(consentVC, animated: true)
    }
}
