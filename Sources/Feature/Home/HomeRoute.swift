// MARK: - Home Route

public enum HomeRoute: Hashable {
    /// 상세 화면. 값 전체가 아니라 식별자만 전달해 stale을 방지한다.
    /// 대상 화면이 진입 시 Repository에서 최신 데이터를 조회한다.
    case detail(itemID: String)
}
