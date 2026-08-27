import Combine
import Foundation

import Core
import Domain
import Data
import Networks
import AuthFeatureInterface
import AuthFeature
import DrugIdentificationFeatureInterface
import DrugIdentificationFeature
import TimerFeatureInterface
import TimerFeature

/*
 RegisterDependencies

 앱의 의존성 조립 지점(Composition Root). AppDelegate.didFinishLaunching 에서 프로세스당 1회 호출된다.
 "무엇을 쓸지"를 여기 한 곳에서만 결정하고, 각 화면은 프로토콜만 알고 구현체는 모른다.

   register()  →  container.register(프로토콜) { 구현체 }   // 조립: 여기서만
   화면        →  container.resolve(프로토콜)               // 사용: 어디서나

 조립 순서는 의존 방향을 따른다.
   Service(네트워크) → Repository(데이터 접근) → UseCase(비즈니스 로직) → Builder(화면 생성)

 register 클로저는 즉시 실행되지 않고 resolve 시점에 평가된다(지연 생성).
 따라서 등록 순서가 참조 순서보다 앞설 필요는 없지만, 읽는 사람을 위해 의존 방향대로 배치한다.
 */
enum RegisterDependencies {
    /*
     타이머 완료/취소 분석 구독 보관.

     Combine 구독은 AnyCancellable 이 해제되는 순간 끊긴다.
     이 구독의 대상인 TimerUseCase 는 컨테이너에 캐싱되어 앱 수명 내내 살아있으므로,
     구독 역시 같은 수명을 갖도록 static 프로퍼티에 보관한다.
     (지역 변수에 담으면 register() 반환 직후 해제되어 이벤트가 조용히 사라진다)
     */
    
    /*
     AnyCancellabel이란?
     취소 시 지정된 클로저를 실행하는, 타입이 지워진 취소 가능 객체
     해제될 때 자동으로 cancel()을 부른다. 이게 핵심입니다. 지역 변수로 받으면 함수 끝에서 해제 → 자동 cancel() → 구독 종료.
     
     canel() - 컴바인 구독을 그만하는 용도의 함수. AnyCancellabel이 자동으로 부르기 때문에 직접 호출할 일 거의 없음.
     */
    private static var analyticsBag = Set<AnyCancellable>()

    static func register() {
        // DIContainer.shared — 앱 전역에 하나뿐인 DI 컨테이너 인스턴스(static let 싱글톤).
        // container는 이를 참조하는 변수
        // 지역 상수로 받아두는 건 아래에서 register 를 여러 번 호출하기 때문(반복 표기 축약).
        let container = DIContainer.shared

        // MARK: - Network Services
        // 네트워크 계층. Repository 가 주입받아 쓰므로 가장 먼저 준비한다.
        let pillService = DefaultPillService.standard
        let authService = DefaultAuthService.standard

        // MARK: - Repositories
        // 데이터 출처(서버·로컬)를 감추는 계층. UseCase 는 프로토콜만 보고 구현을 모른다.
        container.register(PillRepositoryProtocol.self) {
            PillRepository(service: pillService)
        }
        container.register(TimerRepositoryProtocol.self) {
            TimerRepository()
        }
        container.register(AuthRepositoryProtocol.self) {
            AuthRepository(service: authService)
        }

        /*
         알람 스케줄러 — OS 버전에 따라 구현체가 갈리는 유일한 지점.

         타이머는 iOS 26.1+ 전용이다. 백그라운드에서 처치 시각을 보장할 수 있는 건 AlarmKit(시스템 알람)뿐이고,
         그 미만 버전은 타이머 탭이 안내 화면만 띄우므로 스케줄러가 실제로 호출되지 않는다.

         그럼에도 26.1 미만에 no-op 을 등록해두는 이유:
         SceneDelegate 가 OS 버전과 무관하게 TimerUseCase 를 resolve 하므로,
         등록이 비어 있으면 그 시점에 의존성 해석이 실패한다.
         "쓰이지 않지만 존재해야 하는" 자리를 UnavailableAlarmScheduler 가 채운다.
         */
        container.register(TimerAlarmScheduling.self) {
            if #available(iOS 26.1, *) {
                return AlarmKitAlarmScheduler()
            }
            return UnavailableAlarmScheduler()
        }

        // MARK: - UseCases
        // 비즈니스 로직 계층. resolve 결과가 캐싱(싱글톤)되어 앱 전체가 같은 인스턴스를 공유한다.
        container.register(PillUseCase.self) {
            DefaultPillUseCase(repository: container.resolve(PillRepositoryProtocol.self))
        }

        container.register(AuthUseCase.self) {
            DefaultAuthUseCase(repository: container.resolve(AuthRepositoryProtocol.self))
        }

        /*
         TimerUseCase 등록 — 단순 생성이 아니라 세 가지 배선이 함께 이뤄진다.
           1) 워치 명령 핸들러 연결
           2) 타이머 종료 신호 → 분석 이벤트 번역
           3) 알람 권한 응답 → 분석 이벤트 번역

         2·3을 여기서 하는 이유: Domain 계층은 분석 SDK를 알면 안 된다.
         UseCase 는 "타이머가 끝났다"는 순수 신호만 방출하고,
         그 신호를 Amplitude 이벤트로 바꾸는 책임은 조립 지점인 여기가 진다.
         */
        container.register(TimerUseCase.self) {
            let sync = TimerWatchSyncService.shared
            let useCase = DefaultTimerUseCase(
                repository: container.resolve(TimerRepositoryProtocol.self),
                alarmScheduler: container.resolve(TimerAlarmScheduling.self),
                watchSync: sync
            )

            /*
             워치 명령 → 폰 UseCase 실행(알람 예약 포함) → 스냅샷 재브로드캐스트.

             resolve 캐싱(싱글톤)이라 화면에 붙은 UseCase 와 동일 인스턴스가 명령을 처리한다.
             즉 워치에서 시작해도 폰 UI가 즉시 같은 상태를 반영한다.
             
             [weak useCase] — 캡처 리스트. 클로저가 바깥 변수를 어떻게 잡을지 지정하는 자리로,
             항상 파라미터(command) 앞에 온다. 기본은 강한 캡처이고 weak 를 명시해야 약해진다.
             캡처는 usecase를 참조한다는 개념이다.
             
             이 클로저는 sync(싱글톤)의 프로퍼티에 저장되어 앱 수명 내내 살아있다.
             강하게 잡으면 컨테이너가 캐시를 비워도(재등록 시) 옛 useCase 가 해제되지 못하고,
             워치 명령을 새 인스턴스가 아닌 옛 인스턴스가 계속 처리하게 된다. 강한 참조와 약한 참조의 가장 큰 차이는 ARC가 증가하는지 안 하는지 차이이다.
             */
            sync.commandHandler = { [weak useCase] command in
                guard let useCase else { return }
                // 워치에서 시작한 경우만 여기서 별도 집계(source=watch).
                // 폰에서 시작한 경로는 각 화면에서 source=phone 으로 찍으므로 중복되지 않는다.
                if case let .start(presetId) = command,
                   let preset = useCase.presets.value.first(where: { $0.id == presetId }) {
                    AppAnalytics.track(.timerStart(
                        source: "watch",
                        presetLabel: preset.label,
                        category: preset.category.displayName,
                        durationSec: preset.duration
                    ))
                }
                useCase.handleWatchCommand(command)
            }

            /*
             타이머 완료/취소 → 분석 이벤트 번역.

             종료 경로가 여러 갈래(카드의 [완료]/정지, 풀스크린 알람, 알림 액션, 워치 remove)지만
             전부 remove(id:) 로 합류하므로 집계 지점은 이 한 곳이면 충분하다.
             (앱 밖에서 처리되는 AlarmKit [완료] 는 이 경로를 타지 않아 별도 처리 대상)

             완료와 취소의 파라미터가 다른 이유: 취소는 "얼마나 쓰다 껐는지"가 분석 대상이라
             경과·잔여 시간을 함께 남긴다.
             */
            useCase.timerEnded
                .sink { info in
                    switch info.reason {
                    case .completed:
                        AppAnalytics.track(.timerComplete(
                            category: info.category.displayName,
                            durationSec: info.durationSec
                        ))
                    case .cancelled:
                        AppAnalytics.track(.timerCancel(
                            category: info.category.displayName,
                            elapsedSec: info.elapsedSec,
                            remainingSec: info.remainingSec
                        ))
                    }
                }
                .store(in: &Self.analyticsBag)

            // 알람 권한 프롬프트 응답 → permission_result(alarm).
            // gate="timer" — 어느 진입점에서 권한을 물었는지 구분해 거부율을 화면별로 본다.
            useCase.alarmPermissionPrompted
                // sink — 신호(true/false)가 올 때마다 이 클로저를 실행한다. 여기서 신호는 granted이다.
                .sink { granted in
                    AppAnalytics.track(.permissionResult(
                        permission: "alarm", result: granted ? "granted" : "denied", gate: "timer"))
                }
                // store — sink 가 반환한 구독(AnyCancellable)을 보관해 살려둔다.
                // 빼먹으면 아무도 잡지 않아 즉시 해제되고, 크래시 없이 이벤트만 조용히 사라진다.
                /*
                 구독을 왜 보관함에 담아둬야하지? : sink가 계약서를 하나 뱉기 때문에
                */
                .store(in: &Self.analyticsBag)
            /*
             publisher
                 .sink { 값 in ... }      // 받기
                 .store(in: &보관함)       // 살려두기
             */

            return useCase
        }

        // MARK: - Feature Builders
        // 각 기능 모듈의 화면 조립 담당. Coordinator 가 이걸 통해 화면을 만들므로
        // 모듈 간에 ViewController 타입을 직접 참조하지 않는다.
        container.register(DrugIdentificationFeatureBuildable.self) {
            DrugIdentificationBuilder()
        }
        container.register(TimerFeatureBuildable.self) {
            TimerBuilder()
        }
        container.register(AuthFeatureBuildable.self) {
            AuthBuilder()
        }

        observeSignOut(container: container)
    }

    /*
     계정 스코프 캐시 폐기 (NM-410).

     로그아웃·탈퇴 시 계정에 딸린 값은 전부 버린다 — 병동 공용 기기에서 앞사람의 잔여 식별 횟수가
     다음 사람에게 보이면 안 된다(spec: feature/auth/README.md §계정 스코프 캐시 폐기).

     AuthUseCase 가 다른 UseCase 를 직접 부르지 않는 이유: Domain 안에서 UseCase 끼리 엮이면
     "로그아웃이 알약 화면을 안다"가 되어 의존이 뒤엉킨다. 신호만 던지고, 무엇을 지울지는
     전체를 아는 조립 지점인 여기가 정한다.
     */
    private static func observeSignOut(container: DIContainer) {
        NotificationCenter.default.addObserver(
            forName: .authDidSignOut,
            object: nil,
            queue: .main
        ) { _ in
            container.resolve(PillUseCase.self).resetAccountScopedState()
        }
    }
}
