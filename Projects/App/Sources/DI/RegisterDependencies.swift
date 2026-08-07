import Combine
import Core
import Domain
import Data
import Networks
import DrugIdentificationFeatureInterface
import DrugIdentificationFeature
import TimerFeatureInterface
import TimerFeature

enum RegisterDependencies {
    /// 타이머 완료/취소 분석 구독 보관 — 앱 수명 동안 유지(UseCase 싱글톤과 함께).
    private static var analyticsBag = Set<AnyCancellable>()

    static func register() {
        let container = DIContainer.shared

        // Network Services
        let pillService = DefaultPillService.standard

        // Repositories
        container.register(PillRepositoryProtocol.self) {
            PillRepository(service: pillService)
        }
        container.register(TimerRepositoryProtocol.self) {
            TimerRepository()
        }
        container.register(TimerAlarmScheduling.self) {
            // 타이머는 iOS 26.1+ 전용 — AlarmKit(시스템 알람)만 처치 시각을 보장한다.
            // 그 미만은 타이머 탭이 안내 화면만 띄우므로 호출되지 않는 no-op 을 등록한다
            // (SceneDelegate 가 버전 무관하게 TimerUseCase 를 resolve 해서 등록 자체는 필요).
            if #available(iOS 26.1, *) {
                return AlarmKitAlarmScheduler()
            }
            return UnavailableAlarmScheduler()
        }

        // UseCases
        container.register(PillUseCase.self) {
            DefaultPillUseCase(repository: container.resolve(PillRepositoryProtocol.self))
        }

        container.register(TimerUseCase.self) {
            let sync = TimerWatchSyncService.shared
            let useCase = DefaultTimerUseCase(
                repository: container.resolve(TimerRepositoryProtocol.self),
                alarmScheduler: container.resolve(TimerAlarmScheduling.self),
                watchSync: sync
            )
            // 워치 명령 → 폰 UseCase 실행(알람 예약 포함) → 스냅샷 재브로드캐스트.
            // resolve 캐싱(싱글톤)이라 UI와 같은 인스턴스가 명령을 처리한다.
            sync.commandHandler = { [weak useCase] command in
                guard let useCase else { return }
                // 워치에서 시작한 프리셋 분석 (timer_start, source=watch) — 아이폰/워치 DAU 구분용.
                if case let .start(presetId) = command,
                   let preset = useCase.presets.value.first(where: { $0.id == presetId }) {
                    AppAnalytics.track(.timerStart(
                        source: "watch",
                        presetLabel: preset.label,
                        category: preset.category.displayName,
                        durationSec: preset.duration
                    ))
                }
                useCase.handleWatchCommand(command)
            }
            // 타이머 완료/취소 → 분석 이벤트 번역 (Domain 은 순수 신호만 방출).
            // 인앱 경로(카드 [완료]/정지·풀스크린 알람·알림 액션·워치 remove)가 전부
            // remove(id:) 로 모여 여기서 한 번에 집계된다. (앱 밖 AlarmKit [완료]는 후속)
            useCase.timerEnded
                .sink { info in
                    switch info.reason {
                    case .completed:
                        AppAnalytics.track(.timerComplete(
                            category: info.category.displayName,
                            durationSec: info.durationSec
                        ))
                    case .cancelled:
                        AppAnalytics.track(.timerCancel(
                            category: info.category.displayName,
                            elapsedSec: info.elapsedSec,
                            remainingSec: info.remainingSec
                        ))
                    }
                }
                .store(in: &Self.analyticsBag)
            // 알람 권한 프롬프트 응답 → permission_result(alarm) 번역.
            useCase.alarmPermissionPrompted
                .sink { granted in
                    AppAnalytics.track(.permissionResult(
                        permission: "alarm", result: granted ? "granted" : "denied", gate: "timer"))
                }
                .store(in: &Self.analyticsBag)
            return useCase
        }

        // Feature Builders
        container.register(DrugIdentificationFeatureBuildable.self) {
            DrugIdentificationBuilder()
        }
        container.register(TimerFeatureBuildable.self) {
            TimerBuilder()
        }
    }
}
