//
//  MetaAdsService.swift
//  Core
//

import AppTrackingTransparency
import Foundation
import UIKit

import FacebookCore

/// Meta 광고 어트리뷰션 채널 (NM-465).
///
/// ## 제품 지표가 아니다
///
/// Firebase 와 방향이 반대다. Firebase 는 **우리가 보려고** 모으고, 여기는 **Meta 가 보고
/// 자기 광고를 최적화하라고** 넘긴다. Meta 는 유저 단위 어트리뷰션을 외부에 내보내지 않으므로,
/// 전환 신호를 되돌려주지 않으면 "이 캠페인에서 몇 명 가입했나" 를 알 방법이 없다.
/// 둘은 대체 관계가 아니라 역할이 다르다 (docs: `Meta광고-어트리뷰션-설계.md`).
///
/// ## 화이트리스트만 노출한다
///
/// 범용 `log(event:)` 를 두지 않는다. **보낼 이벤트마다 전용 메서드를 만든다.**
/// 자동 수집도 Info.plist(`FacebookAutoLogAppEventsEnabled=false`)와 런타임 양쪽에서 끈다.
///
/// 이유는 이 채널의 성질에 있다 — 앱은 그 사용자가 Meta 광고를 보고 왔는지 **모른다**.
/// 광고 노출 기록은 Meta 가 갖고 있어서, 매칭은 Meta 서버에서 일어난다. 즉 **전원의 이벤트가
/// 나간다.** 오가닉으로 들어온 사용자, 지인 추천으로 온 사용자도 예외가 아니고, 매칭에 실패한
/// 기록도 Meta 가 유사타겟·전환 예측 모델에 쓴다.
///
/// 그래서 이벤트를 한 줄 늘릴 때마다 **전 사용자의 그 행동이 Meta 에 쌓인다.** 목록이 짧아야 하는
/// 건 취향이 아니라 이 구조 때문이다.
///
/// ## 제품 이벤트는 보내지 않는다
///
/// `AnalyticsEvent` 의 17개는 **전부 제외**다. 이유는 둘이다.
///
/// **① 광고 최적화에 쓸모가 없다.** 캠페인은 이벤트 하나를 목표로 잡고 그걸 일으킬 사람을 찾는데,
/// 그 목표는 가입·결제지 앱 내 행동이 아니다. `pill_identify_result` 를 보낸다고 Meta 가
/// 더 나은 사람을 찾아주지 않는다. 얻는 것 없이 §화이트리스트의 대가만 치른다.
///
/// **② 자유 입력 필드가 섞여 있다.** `preset_label` 은 사용자가 직접 타이핑하는 처치명이라
/// 무엇이 들어올지 앱이 통제할 수 없다. 환자 이름이나 처치 내용이 적혀도 막을 방법이 없고,
/// 그런 값이 외부 광고 플랫폼으로 나가면 되돌릴 수 없다.
///
/// (이 앱이 **간호사의 업무 도구**라는 점은 짚어둔다 — 사용자 본인의 건강 상태를 다루지 않으므로
///  "앱을 쓴다" 는 사실 자체는 민감정보가 아니다. 제외 근거는 위 둘이지 데이터 유형이 아니다.)
public enum MetaAdsService {

    /// `FirebaseService.configure()` 뒤에 부른다.
    ///
    /// 자동 수집을 **런타임에서도** 끈다. Info.plist 로 이미 껐지만, SDK 가 런타임 설정을 저장·우선하는
    /// 구조라 구성값으로 다시 박아 둔다(`FirebaseService.setAnalyticsCollectionEnabled` 와 같은 이유).
    /// 이게 없으면 붙이는 순간 무슨 이벤트가 나가는지 모르는 상태가 된다.
    public static func configure(
        _ application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        Settings.shared.isAutoLogAppEventsEnabled = false
        // IDFA 수집 자체는 켜 두되, 실제 수집 여부는 ATT 동의가 가른다 —
        // 거부하면 SKAdNetwork 경로로만 집계된다.
        Settings.shared.isAdvertiserIDCollectionEnabled = true

        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - ATT

    /// 추적 권한을 묻는다. **앱을 처음 켠 직후가 아니라 홈에 들어간 뒤** 부른다.
    ///
    /// 시점이 옵트인율을 좌우한다 — 콜드런치 즉시 물으면 무슨 앱인지도 모르는 상태라 대개 거부한다.
    /// 로그인·동의를 마치고 홈에 도착한 시점이면 앱이 뭘 하는지 이미 봤고, 동의 흐름의 연장선이라
    /// 맥락이 이어진다.
    ///
    /// 거부해도 광고는 돌아간다 — IDFA 없이 SKAdNetwork 집계로 측정된다. 정밀도만 낮아진다.
    ///
    /// 시스템이 한 번만 띄우므로 `.notDetermined` 일 때만 요청한다. 앱이 **활성 상태**여야
    /// 프롬프트가 뜨므로, 전환 애니메이션이 끝난 뒤 부를 것.
    public static func requestTrackingAuthorizationIfNeeded() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        ATTrackingManager.requestTrackingAuthorization { _ in
            // 결과를 우리가 저장할 필요는 없다 — SDK 가 상태를 직접 읽어 IDFA 사용 여부를 정한다.
        }
    }

    // MARK: - 화이트리스트 이벤트

    /// 가입 완료 — 캠페인 최적화 목표.
    ///
    /// **로그인 성공이 아니라 필수 동의까지 마친 시점**에 부른다. 이 앱은 동의를 마쳐야 홈에
    /// 들어가므로(spec: feature/auth/README.md §진입 라우팅) 로그인만 한 사람은 실질 가입자가 아니다.
    /// 로그인 경로와 개정 재동의 경로가 모두 `AuthCoordinator.onFinished` 로 모이므로 그 한 자리면 된다.
    public static func logCompleteRegistration() {
        AppEvents.shared.logEvent(.completedRegistration)
    }
}
