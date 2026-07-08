import Core
import Domain
import Data
import Networks
import DrugIdentificationFeatureInterface
import DrugIdentificationFeature
import TimerFeatureInterface
import TimerFeature

enum RegisterDependencies {
    static func register() {
        let container = DIContainer.shared

        // Network Services
        let homeAPIService = DefaultHomeAPIService()
        let pillService = DefaultPillService.standard

        // Repositories
        container.register(HomeRepositoryProtocol.self) {
            HomeRepository(service: homeAPIService)
        }
        container.register(PillRepositoryProtocol.self) {
            PillRepository(service: pillService)
        }
        container.register(TimerRepositoryProtocol.self) {
            TimerRepository()
        }
        container.register(TimerAlarmScheduling.self) {
            // iOS 26.1+ → AlarmKit(시스템 알람, 무음/잠금/강제종료 뚫음).
            // 미만 → 커스텀 방식(단발 알림 + 반복 폴백 + 백그라운드 오디오).
            if #available(iOS 26.1, *) {
                return AlarmKitAlarmScheduler()
            }
            return CustomAlarmScheduler()
        }

        // UseCases
        container.register(HomeUseCaseProtocol.self) {
            DefaultHomeUseCase(repository: container.resolve(HomeRepositoryProtocol.self))
        }
        container.register(PillUseCase.self) {
            DefaultPillUseCase(repository: container.resolve(PillRepositoryProtocol.self))
        }

        container.register(TimerUseCase.self) {
            DefaultTimerUseCase(
                repository: container.resolve(TimerRepositoryProtocol.self),
                alarmScheduler: container.resolve(TimerAlarmScheduling.self),
                watchSync: TimerWatchSyncService.shared
            )
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
