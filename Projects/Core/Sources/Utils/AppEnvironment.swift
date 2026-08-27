import Foundation

/// 빌드 성격 판별.
///
/// `isInternal` = 개발자 내부 테스트 빌드 여부.
///  - **DEBUG**: Xcode 실행 빌드.
///  - **INTERNAL**: 내부 TestFlight 빌드 — fastlane `beta_internal` 레인이
///    `SWIFT_ACTIVE_COMPILATION_CONDITIONS`에 `INTERNAL`을 넣어 컴파일 조건으로 주입한다.
///
/// 이 값이 `true`면 **Amplitude 전송** 과 **학습용 S3 원본 이미지 업로드**를 하지 않는다 —
/// 둘 다 환경이 갈려 있지 않아(단일 Amplitude 프로젝트·단일 S3 버킷) 내부 테스트 데이터가
/// 그대로 운영 지표·데이터셋을 오염시키기 때문이다.
/// (외부 TestFlight·App Store 프로덕션은 `false` → 정상 수집)
///
/// **Firebase Analytics는 여기서 갈리지 않는다.** dev/prod Firebase 프로젝트가 분리돼 있어
/// 내부 빌드는 dev 속성으로 수집한다 — `isAnalyticsCollectionEnabled` 참고.
///
/// Crashlytics(크래시)·App Check·Remote Config는 내부에서도 유지한다(SaaS 지표와 무관, 디버깅에 유용).
public enum AppEnvironment {
    public static var isInternal: Bool {
        #if DEBUG || INTERNAL
        return true
        #else
        return false
        #endif
    }

    /// Firebase Analytics 수집 여부.
    ///
    /// 단일 소스는 빌드 구성의 `FIREBASE_ANALYTICS_ENABLED`(→ Info.plist
    /// `FIREBASE_ANALYTICS_COLLECTION_ENABLED`)이고, 이 값은 그걸 읽어 런타임에 다시 박기 위한 것이다.
    /// SDK가 런타임 설정값을 디스크에 저장하고 우선하므로, 이전 실행에서 꺼둔 값이 남는 걸 막는다.
    ///
    /// 구성 주입이 실패해 키가 없으면 Firebase 기본값(수집 ON)을 따른다.
    public static var isAnalyticsCollectionEnabled: Bool {
        switch Bundle.main.object(forInfoDictionaryKey: "FIREBASE_ANALYTICS_COLLECTION_ENABLED") {
        case let flag as Bool:   return flag
        case let text as String: return !["NO", "FALSE", "0"].contains(text.uppercased())
        default:                 return true
        }
    }
}
