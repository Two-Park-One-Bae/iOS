//
//  ConsentSettingsViewModel.swift
//  AuthFeature
//

import Combine
import Foundation

import Core
import Domain

/// 설정 > 약관 및 동의 — 선택 동의의 철회·재동의 (NM-548).
///
/// 동의 온보딩과 별개다. 약관 전문을 확인하고 **선택 항목의 동의 여부만** 바꾼다
/// (spec: feature/auth/README.md §약관 및 동의 화면).
///
/// 체크를 바꾼다고 바로 반영되지 않는다. 설정 행에서 곧장 켜고 끄는 토글은 실수로 바뀌기 쉽고
/// 약관을 다시 확인할 자리도 없어서, `저장`을 눌러야 보낸다.
public final class ConsentSettingsViewModel {

    // MARK: - Output

    /// 화면에 그릴 항목 — 필수가 먼저, 선택이 뒤. 필수는 체크된 채 고정이다.
    public let definitions = CurrentValueSubject<[ConsentDefinition], Never>([])
    /// 체크된 **선택** 항목. 필수 항목은 여기 넣지 않는다(바꿀 수 없으므로).
    public let checked = CurrentValueSubject<Set<ConsentType>, Never>([])
    public let isLoading = CurrentValueSubject<Bool, Never>(false)
    public let errorMessage = PassthroughSubject<String, Never>()

    /// `저장` 활성 조건 — 선택 항목의 체크가 저장된 상태와 달라졌을 때만.
    public var canSave: AnyPublisher<Bool, Never> {
        checked.combineLatest(saved)
            .map { $0 != $1 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// 서버에 저장된 선택 항목의 동의 상태. 저장이 성공하면 지금 체크로 바뀐다.
    private let saved = CurrentValueSubject<Set<ConsentType>, Never>([])

    @Injected private var useCase: AuthUseCase

    public init() {}

    // MARK: - Input

    public func load() {
        isLoading.send(true)

        Task { @MainActor in
            defer { isLoading.send(false) }

            do {
                let loaded = try await useCase.fetchConsentDefinitions()
                // 옛 버전에 동의한 상태·응답한 적 없는 상태는 체크되지 않은 것으로 보인다.
                // 체크를 먼저 보낸다 — 화면은 항목이 도착할 때 지금 체크로 행을 그린다.
                let agreed = Set(
                    loaded.filter { !$0.isRequired && useCase.user.value?.hasAgreed(to: $0.type) == true }.map(\.type)
                )
                saved.send(agreed)
                checked.send(agreed)
                // 서버에 선택 항목 정의가 아직 없으면(앱이 먼저 배포된 기간) 필수 항목만 보인다 —
                // 받은 것만 그리므로 따로 가를 것이 없다.
                definitions.send(loaded.filter(\.isRequired) + loaded.filter { !$0.isRequired })
            } catch AuthError.updateRequired {
                errorMessage.send(ConsentMessage.updateRequired)
            } catch {
                errorMessage.send("약관을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }

    public func toggle(_ type: ConsentType) {
        guard definitions.value.contains(where: { $0.type == type && !$0.isRequired }) else { return }
        var next = checked.value
        next.formSymmetricDifference([type])
        checked.send(next)
    }

    /// 바뀐 선택 항목만 현재 버전으로 보낸다(체크 `agreed=true` · 해제 `agreed=false`).
    /// 확인 다이얼로그는 띄우지 않는다 — 철회가 동의보다 번거로우면 안 된다(개인정보 보호법 제38조 제4항).
    public func save() {
        guard !isLoading.value else { return }

        let current = checked.value
        let changes = definitions.value
            .filter { !$0.isRequired && current.contains($0.type) != saved.value.contains($0.type) }
            .map { ConsentAgreement(type: $0.type, version: $0.version, agreed: current.contains($0.type)) }
        guard !changes.isEmpty else { return }

        isLoading.send(true)

        Task { @MainActor in
            do {
                try await useCase.updateOptionalConsents(changes)
                isLoading.send(false)
                saved.send(current)
            } catch AuthError.consentVersionMismatch {
                // 그 사이 서버가 버전을 올렸다 — 다시 받아 새 버전으로 그린다. 옛 버전에 걸었던 체크는
                // 새 버전에 대한 응답이 아니므로 버려진다.
                isLoading.send(false)
                errorMessage.send(ConsentMessage.reloaded)
                load()
            } catch {
                isLoading.send(false)
                checked.send(saved.value)
                errorMessage.send("저장하지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }
}
