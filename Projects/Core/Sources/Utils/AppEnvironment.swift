import Foundation

/// 빌드 성격 판별.
///
/// `isInternal` = 개발자 내부 테스트 빌드 여부.
///  - **DEBUG**: Xcode 실행 빌드.
///  - **INTERNAL**: 내부 TestFlight 빌드 — fastlane `beta_internal` 레인이
///    `SWIFT_ACTIVE_COMPILATION_CONDITIONS`에 `INTERNAL`을 넣어 컴파일 조건으로 주입한다.
///
/// 이 값이 `true`면 **Analytics SaaS 전송(Amplitude·Clarity·Firebase Analytics)** 과
/// **학습용 S3 원본 이미지 업로드**를 하지 않는다 — 내부 테스트 데이터로 지표·데이터셋이 오염되는 걸 막는다.
/// (외부 TestFlight·App Store 프로덕션은 `false` → 정상 수집)
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
}
