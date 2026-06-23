import Core
import Domain
import Data
import Networks

enum RegisterDependencies {
    static func register() {
        let container = DIContainer.shared

        // Network Services
        let homeAPIService = DefaultHomeAPIService()

        // Repositories
        container.register(HomeRepositoryProtocol.self) {
            HomeRepository(service: homeAPIService)
        }

        // UseCases
        container.register(HomeUseCaseProtocol.self) {
            DefaultHomeUseCase(repository: container.resolve(HomeRepositoryProtocol.self))
        }
    }
}
