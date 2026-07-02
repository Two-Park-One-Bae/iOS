import Core
import Domain
import Data
import Networks
import DrugIdentificationFeatureInterface
import DrugIdentificationFeature

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

        // UseCases
        container.register(HomeUseCaseProtocol.self) {
            DefaultHomeUseCase(repository: container.resolve(HomeRepositoryProtocol.self))
        }
        container.register(PillUseCase.self) {
            DefaultPillUseCase(repository: container.resolve(PillRepositoryProtocol.self))
        }

        // Feature Builders
        container.register(DrugIdentificationFeatureBuildable.self) {
            DrugIdentificationBuilder()
        }
    }
}
