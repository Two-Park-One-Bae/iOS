import Combine

public final class DrugIdentificationViewModel {

    public struct Input {
        let viewDidLoad: AnyPublisher<Void, Never>
    }

    public struct Output {
        let isLoading: AnyPublisher<Bool, Never>
    }

    public init() {}

    public func transform(input: Input) -> Output {
        let isLoading = Just(false).eraseToAnyPublisher()
        return Output(isLoading: isLoading)
    }
}
