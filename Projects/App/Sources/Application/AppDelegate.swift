import UIKit
import Core
import Data
import TimerFeature


/*
 AppDelegate vs SceneDelegate

 ┌──────┬─────────────────────────────┬──────────────────────────────────────────────────────┐
 │      │ AppDelegate                 │ SceneDelegate                                        │
 ├──────┼─────────────────────────────┼──────────────────────────────────────────────────────┤
 │ 단위  │ 프로세스 1개                   │ 창(Scene) N개 (여기서 창은 뷰가 아닌 아이폰에서 앱마다 있는 창 하나)│
 │ 시점  │ 앱 시작/종료 시 1회             │ 창이 뜨고 지고 활성화될 때마다.                              │
 │ 예시  │ SDK 초기화, 푸시 토큰           │ window 생성, 화면 갱신                                   │
 │ 생성  │ 앱 시작 시 1개                 │ 창마다 1개 (밀어 닫고 재실행 시 새로 생성)                     │
 │ 콜백  │ 시작 시 1회                    │ willConnectTo 1회 + 활성화마다 반복                       │
 └──────┴─────────────────────────────┴──────────────────────────────────────────────────────┘

 iOS 13 멀티윈도우 도입으로 UI 생명주기가 SceneDelegate로 이관됨.
 (applicationDidBecomeActive → sceneDidBecomeActive 등)
 */

/*
 @main: Swift 5.3(SE-0281)에서 들어온 프로그램 진입점 지정 어트리뷰트.
 붙일 수 있는 조건은 하나이다. — 해당 타입이 static func main()을 갖고 있어야 함.
 컴파일러가 실행 파일의 main 심볼을 합성해, 그 안에서 이 타입의 main()을 호출하도록 연결한다.
 
 UIApplicationDelegate 프로토콜은 static func main()의 기본 구현을 제공하고,
 그 구현이 UIKit의 전역 C 함수 UIApplicationMain(argc, argv, principalClass, delegateClass)을 호출한다.
 따라서 @main final class AppDelegate: UIApplicationDelegate 는
 "이 클래스를 delegate 인자로 넘겨 UIApplicationMain을 실행하라"의 축약이다.
 (UIApplicationMain은 런루프에 진입해 리턴하지 않으며, didFinishLaunching은 그 안에서 콜백으로 불린다.)
 
 - UIApplicationDelegate: 프로세스 단위 시스템 이벤트 창구.
   "앱 실행됨 / 푸시 도착 / 메모리 경고" 등을 시스템이 여기로 알려준다.
   iOS 13+ Scene 기반 앱에서는 UI 생명주기(활성화·백그라운드 전환)가 SceneDelegate로 이관되어,
   여기엔 화면과 무관하게 프로세스당 한 번 실행되는 초기화만 남긴다.

 - UIResponder: responder chain의 최종 종착지가 되기 위한 상속.
   (view → viewController → window → UIApplication → AppDelegate 순으로 미처리 이벤트가 전달됨)
   실제로 여기까지 올라오는 이벤트는 거의 없어 관례적 상속에 가깝다.
   제거 시 NSObject 상속 필요 — UIApplicationMain이 클래스명으로 런타임 인스턴스를 생성하기 때문.
 
 */
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /*
     application(_:didFinishLaunchingWithOptions:) -
     
     UIApplicationDelegate 프로토콜에 정의된 메서드. 이름은 고정이며(오타 시 호출되지 않고 에러도 없음),
     내가 호출하는 것이 아니라 앱 실행 준비가 끝난 시점에 UIKit이 자동으로 불러준다.
     프로세스당 1회만 실행 → 앱 시작 시 한 번만 해야 하는 초기화를 넣는 자리.
     (백그라운드 복귀 시에도 다시 실행돼야 하는 작업은 SceneDelegate로)

     - application: 호출 주체인 UIApplication 싱글턴(= UIApplication.shared).
                    델리게이트 관례상 전달되며 대개 사용하지 않는다.
     - launchOptions: 앱이 실행된 이유. 푸시 탭·URL 스킴 등으로 켜졌을 때 그 정보가 담기고,
                      아이콘 탭 등 일반 실행에서는 nil.
     - 반환값: 실행 계속 여부. URL 처리를 거부할 때만 false, 실무에선 true 고정.
     */
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        RegisterDependencies.register()
        // App Check 팩토리는 반드시 FirebaseApp.configure() 이전에 설정해야 적용된다.
        AppCheckService.configure()
        FirebaseService.configure()

        // 소셜 로그인 SDK 초기화 (NM-410). Firebase 설정 뒤에 온다 —
        // 구글은 GoogleService-Info.plist 의 CLIENT_ID 를 읽고, 카카오는 앱 키가 필요하다.
        SocialLoginSDK.configure()

        // Firebase Analytics — dev/prod 프로젝트가 분리돼 있어 내부 빌드도 수집한다(dev 속성).
        //   주 통제는 Info.plist FIREBASE_ANALYTICS_COLLECTION_ENABLED(구성별)로 init 전부터 적용된다
        //   — 런타임 disable만으론 first_open 등이 새는 게 확인됨(firebase-ios-sdk#5837).
        //   아래 호출은 보강 — SDK가 런타임 값을 저장·우선하므로 구성값으로 다시 박는다.
        FirebaseService.setAnalyticsCollectionEnabled(AppEnvironment.isAnalyticsCollectionEnabled)

        // Amplitude·S3 원본 업로드는 환경이 갈려 있지 않아(단일 프로젝트·단일 버킷) 내부 빌드에서 막는다.
        // Crashlytics(크래시)·App Check·Remote Config는 내부에서도 유지 — dev 프로젝트로 분리돼 있다.
        let isInternal = AppEnvironment.isInternal

        // Crashlytics userID(= 기기 식별자)는 내부에서도 붙인다(크래시 리포트 식별).
        let deviceID = DeviceIdentifier.current
        if let deviceID {
            FirebaseService.setUserID(deviceID)
        }

        if !isInternal {
            // 외부 TestFlight·프로덕션에서만 Amplitude 수집.
            // Amplitude·Crashlytics를 같은 device_id로 묶어 서버 로그와 교차 대조 가능하게 한다.
            if let deviceID {
                AmplitudeService.setUserID(deviceID)
            }
            AmplitudeService.track(AppLaunchEvent())
        }
        // Remote Config fetch + 게이팅(강제 업데이트·점검)은 window 를 소유한 SceneDelegate 가
        // sceneDidBecomeActive 에서 담당한다(포그라운드 복귀 시에도 최신값 반영).
        // 타이머 알람은 AlarmKit(26.1+)이 단독 담당한다 — 시스템 알람과 카운트다운 위젯까지
        // 시스템이 처리하므로 앱이 켜둘 스택이 없다. 26.1 미만은 타이머 탭이 안내만 띄운다.
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
