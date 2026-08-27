//
//  ConsentViewModel.swift
//  AuthFeature
//
//  Created by 바견규 on 8/28/26.
//

import Combine
import Foundation

import Core
import Domain

public final class ConsentViewModel {

    // MARK: - Navigation Callbacks (set by Coordinator)

    /// 동의 저장 완료 — 홈으로.
    public var onCompleted: (() -> Void)?
    /// 취소 확인까지 마쳐 로그아웃했다 — 로그인 화면으로.
    public var onCancelled: (() -> Void)?

    // MARK: - Output

    /// 화면에 그릴 항목. 서버가 소유하는 값이라 로드 전에는 비어 있다.
    public let definitions = CurrentValueSubject<[ConsentDefinition], Never>([])
    /// 항목별 체크 상태. `definitions` 와 같은 순서.
    public let checked = CurrentValueSubject<Set<ConsentType>, Never>([])
    public let isLoading = CurrentValueSubject<Bool, Never>(false)
    public let errorMessage = PassthroughSubject<String, Never>()

    /// 필수 항목이 전부 체크됐는가 — '동의하고 계속' 활성 조건.
    public var canProceed: AnyPublisher<Bool, Never> {
        definitions.combineLatest(checked)
            .map { definitions, checked in
                let required = definitions.filter(\.isRequired).map(\.type)
                return !required.isEmpty && required.allSatisfy { checked.contains($0) }
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    @Injected private var useCase: AuthUseCase

    public init() {}

    // MARK: - Input

    public func load() {
        isLoading.send(true)

        Task { @MainActor in
            defer { isLoading.send(false) }

            do {
                let loaded = try await useCase.fetchConsentDefinitions()
                definitions.send(loaded)
                // 재조회(버전 변경) 상황에서 예전 체크가 남으면 새 버전에 동의한 것처럼 보인다 — 초기화한다.
                checked.send([])
            } catch {
                errorMessage.send("약관을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }

    public func toggle(_ type: ConsentType) {
        var next = checked.value
        next.formSymmetricDifference([type])
        checked.send(next)
    }

    /// '전체 동의' — 하나라도 빠져 있으면 전부 켜고, 이미 다 켜져 있으면 전부 끈다.
    public func toggleAll() {
        let all = Set(definitions.value.map(\.type))
        checked.send(checked.value == all ? [] : all)
    }

    public func agree() {
        guard !isLoading.value else { return }
        isLoading.send(true)

        Task { @MainActor in
            do {
                let route = try await useCase.agreeToConsents(definitions.value)
                isLoading.send(false)
                // 응답의 onboardingRequired 만 신뢰한다. 아직 미충족이면 화면에 남는다.
                if route == .home { onCompleted?() }
            } catch AuthError.consentVersionMismatch {
                // 저장 중 서버가 약관 버전을 올린 경우. 오류로 끝내지 않고 새 버전으로 화면을 다시 그린다
                // (spec: feature/auth/README.md §동의 온보딩).
                isLoading.send(false)
                errorMessage.send("약관이 업데이트됐어요. 새 내용을 확인해 주세요.")
                load()
            } catch {
                isLoading.send(false)
                errorMessage.send("동의 저장에 실패했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }

    /// 취소 확인 다이얼로그에서 로그아웃을 고른 뒤 호출된다.
    /// 동의 없이 홈으로 가는 경로는 없으므로, 취소의 결과는 로그아웃뿐이다.
    public func cancelAndSignOut() {
        useCase.signOut()
        onCancelled?()
    }
}
