//
//  AttributionTracking.swift
//  Core
//

import Foundation

/// 유입 경로 측정 (NM-547, Android NM-543 과 짝).
///
/// ## `AppAnalytics` 와 섞지 않는다
///
/// 둘은 묻는 것이 다르다. Firebase 는 **앱 안에서 무슨 일이 일어났나**를 재고, 여기는
/// **이 사용자가 어디서 왔나**만 잰다. 한 파사드에 합치면 호출부가 어느 쪽으로 가는지를
/// 이름만으로 알 수 없고, 제품 이벤트가 하나씩 광고 지표로 새어 나간다.
///
/// 그래서 **보낼 수 있는 것이 가입 하나**다. 늘리려면 Android 와 이름·시점을 맞춰야 한다.
///
/// 구현(에어브릿지)은 App 타깃에만 있다 — 에어브릿지 SDK 를 App 만 링크할 수 있어서다
/// (`AirbridgeService` 참고). App 이 `RegisterDependencies` 에서 주입한다.
public protocol AttributionTracking {
    /// 가입했다 — **최초 필수 동의 저장이 성공한 그 순간**에만 부른다.
    ///
    /// 국외 이전 동의(`OVERSEAS`, NM-548)가 없으면 구현이 보내지 않는다 — 호출부는 가르지 않는다.
    ///
    /// 약관 개정 재동의는 가입이 아니다. 같은 사람이 약관이 바뀔 때마다 새로 가입한 것으로
    /// 세이면 광고 성과가 부풀려진다. 최초인지는 호출부가 `AuthUser.needsReconsent` 로 가른다.
    func signUp()
}
