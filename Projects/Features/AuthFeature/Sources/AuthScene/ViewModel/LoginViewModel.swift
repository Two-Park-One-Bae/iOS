//
//  LoginViewModel.swift
//  AuthFeature
//
//  Created by 바견규 on 8/28/26.
//

import Combine
import Foundation

import Core
import Domain

public final class LoginViewModel {

    // MARK: - Navigation Callbacks (set by Coordinator)

    /// 로그인 성공 — 다음 화면(동의 온보딩 또는 홈)을 코디네이터가 정한다.
    public var onSignedIn: ((AuthRoute) -> Void)?

    // MARK: - Output

    /// 로그인 진행 중. 버튼 잠금·인디케이터에 쓴다.
    public let isLoading = CurrentValueSubject<Bool, Never>(false)
    /// 사용자에게 보여줄 실패 문구. 취소는 여기로 오지 않는다.
    public let errorMessage = PassthroughSubject<String, Never>()

    @Injected private var useCase: AuthUseCase

    public init() {}

    // MARK: - Input

    public func signIn(with provider: AuthProvider) {
        // 진행 중에 다른 공급자를 누르면 두 로그인이 겹쳐 마지막 것만 반영되는 상태가 된다.
        guard !isLoading.value else { return }
        isLoading.send(true)

        Task { @MainActor in
            defer { isLoading.send(false) }

            do {
                let route = try await useCase.signIn(with: provider)
                onSignedIn?(route)
            } catch AuthError.cancelled {
                // 사용자가 스스로 닫은 것 — 안내를 띄우면 오히려 오작동처럼 보인다.
                return
            } catch {
                errorMessage.send(Self.message(for: error))
            }
        }
    }

    // MARK: - Private

    private static func message(for error: Error) -> String {
        switch error as? AuthError {
        case .kakaoTokenInvalid:
            return "카카오 로그인에 실패했어요. 다시 시도해 주세요."
        case .serviceUnavailable:
            // 카카오·Firebase 일시 장애 — 구글·애플은 영향이 없어 다른 방법을 함께 안내한다.
            return "잠시 연결이 원활하지 않아요. 잠시 후 다시 시도하거나 다른 방법으로 로그인해 주세요."
        default:
            return "로그인에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}
