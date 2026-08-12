import Foundation

/*
 DIContainer

 "이 프로토콜 달라고 하면 이 구현체를 준다"를 기억해두는 창고.
 만드는 곳(RegisterDependencies)과 쓰는 곳(화면·SceneDelegate)을 분리하기 위해 존재한다.

   register(프로토콜) { 구현체 }   // 창고에 레시피 넣기 — 이 시점에는 아직 안 만든다
   resolve(프로토콜)              // 창고에서 꺼내기 — 처음엔 만들고, 이후엔 만들어둔 걸 재사용

 프로토콜 이름을 문자열로 바꿔 딕셔너리 키로 쓰는 단순한 구조다.
 등록하지 않은 걸 꺼내려 하면 컴파일 에러가 아니라 실행 중 fatalError 로 죽는다.
 (nil 이 조용히 흘러 원인 불명 버그가 되느니, 조립 누락을 개발 중 바로 드러내는 편을 택했다)


 [스코프] 여기 등록된 것은 예외 없이 전부 앱에 하나뿐인 인스턴스다. (Singleton)
 resolve 결과를 무조건 캐싱하므로 "매번 새로 만들기(transient)" 옵션이 없다.
 상태를 가진 의존성(UseCase·Repository)이 매번 새로 만들어지면 구독과 상태가 끊어지는
 버그가 생기므로, 아예 전부 공유하는 쪽으로 통일한 선택이다.
 
    스코프                       동작
 container (싱글톤)    항상 같은 객체 ← 지금 구현은 이것만
 transient           resolve할 때마다 새 객체
 graph / weak        조립 단위나 참조 유지 동안만 공유

 */

public final class DIContainer {
    /// 자기 자신을 자기 안에서 생성. static 은 인스턴스가 아닌 타입에 속하므로 재귀가 생기지 않는다.
    /// static let 은 자동 lazy + swift_once 보장 → 최초 접근 시 딱 한 번, 스레드 안전하게 생성된다.
    public static let shared = DIContainer()

    /// 생성 레시피. 값이 클로저이므로 등록 시점에는 아무것도 만들어지지 않는다(지연 생성).
    /// factories["TimerUseCase"] = { DefaultTimerUseCase(...) }
    private var factories: [String: () -> Any] = [:] // 값 = 만드는 코드(클로저)
    
    /// 생성 완료된 인스턴스 캐시. resolve 결과를 여기 담아 싱글톤처럼 재사용한다.
    /// instances["TimerUseCase"] = (실제 객체)
    private var instances: [String: Any] = [:] // 값 = 만들어진 객체

    /*
     NSLock 이 아니라 NSRecursiveLock 인 것이 핵심.

     resolve 가 락을 잡은 채로 factory() 를 실행하는데, 그 팩토리 내부에서 다시 resolve 를 부른다.
       register(PillUseCase.self) { DefaultPillUseCase(repository: container.resolve(...)) }
     
     일반 NSLock 이면 같은 스레드가 자기가 잡은 락에 막혀 데드락이 된다.
     resolve(A) → 락 획득 🔒
       factory 실행
         resolve(B) → 락 요구... 이미 잠겨있음 → 대기
                      근데 그 락을 푸는 건 나 자신 → 영원히 대기
     
     재진입 가능한 락이라 중첩 resolve 가 통과한다. — NSLock 으로 바꾸지 말 것.
     resolve(A) → 락 획득 🔒 (카운트 1)
       resolve(B) → 같은 스레드 → 통과 🔒 (카운트 2)
         unlock (카운트 1)
       unlock (카운트 0) → 진짜 해제
     
     */
    private let lock = NSRecursiveLock()

    /// 외부 생성 차단 — shared 하나만 존재함을 보장한다.
    private init() {}

    /*
     의존성 등록.

     - type 기본값이 T.self 라 register(factory:) 만으로도 호출 가능하지만,
       반환 타입 추론이 구현체로 잡히지 않도록 프로토콜 타입을 명시하는 편이 안전하다.
     - @escaping: 클로저를 factories 에 저장해 나중에 실행하므로 탈출 클로저다.
     - defer 로 unlock — 중간 return 이나 예외 경로에서도 락 해제가 누락되지 않는다. (defer는 "이 함수가 끝날 때 실행해라"는 예약.)
     */
    public func register<T>(_ type: T.Type = T.self, factory: @escaping () -> T) { // factory 는 함수가 끝난 뒤 factories 에 남아 resolve 때 실행되므로 @escaping 이다.  @escaping — 함수가 끝난 뒤에도 살아있어야 하는 클로저(여기선 factories 에 저장해뒀다가 resolve 에서 실행).
        // () -> T 인 이유: T 로 받으면 인자를 넘기는 순간 이미 생성된다.
        // 클로저로 받아야 생성 시점을 resolve 까지 미룰 수 있고, 그래야 등록 순서에 묶이지 않고
        // 안 쓰는 의존성이 만들어지지 않으며, 캐시를 버려도 다시 만들 수 있다.
        
        //String(describing: TimerUseCase.self)   // → "TimerUseCase"
        let key = String(describing: type) //타입을 문자열로 바꾸는 것이다. 딕셔너리 키로 쓰기 위해서
        
        lock.lock()
        defer { lock.unlock() } // defer는 "이 함수가 끝날 때 실행해라"는 예약.
        factories[key] = factory
        
        instances.removeValue(forKey: key)  // 레시피를 바꿨으니 그 레시피로 만들어둔 옛 인스턴스도 버린다 — 안 버리면 resolve 가 캐시를 먼저 돌려준다.
        /*
         안 버리면 생기는 일.
         register(TimerUseCase.self) { RealUseCase() }
         resolve(TimerUseCase.self)          // Real 생성 → instances에 저장됨

         register(TimerUseCase.self) { MockUseCase() }   // 레시피만 교체
         resolve(TimerUseCase.self)          // 문제 발생: 첫 번째 객체(Real)가 캐시에서 그대로 돌아오는 문제
         */
    }

    /*
     의존성 해석.

     캐시 → 팩토리 실행 → 캐시 저장 순. 즉 첫 resolve 에서만 생성되고 이후로는 같은 객체가 돌아간다.
     */
    public func resolve<T>(_ type: T.Type = T.self) -> T {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }

        // 이미 생성된 인스턴스가 있으면 재사용 (싱글톤) — 같은 타입을 여러 곳에서
        // resolve 해도 항상 동일 인스턴스가 돌아가 상태가 공유된다.
        // (UseCase·Repository 등 상태를 가지는 의존성이 resolve 마다 새로 만들어지면
        //  구독·상태가 끊어지는 치명적 버그가 생긴다 — TimerLiveActivity 참고.)
        if let cached = instances[key] as? T {
            return cached
        }

        // 등록 누락 또는 타입 불일치는 개발 단계에서 잡아야 할 조립 오류이므로 즉시 중단한다.
        guard let factory = factories[key], let value = factory() as? T else {
            fatalError("\(key) is not registered in DIContainer")
        }
        instances[key] = value
        return value
    }
}


/*
 질문: 호출 시에 생성하고 캐시로 등록하는 것 같은데 그냥 DIContainer에 객체 하나씪 넣어놓으면 되는거 아닌가?
 Answer: 네, 됩니다. 그 방식이 실제로 존재하고 Pure DI(수동 조립)라고 부릅니다. 지역 변수로 순서대로 만들면 돼요.
 
 ```
 let timerRepo = TimerRepository()
 let scheduler = AlarmKitAlarmScheduler()
 let timerUseCase = DefaultTimerUseCase(repository: timerRepo, alarmScheduler: scheduler, ...)

 container.register(TimerUseCase.self, instance: timerUseCase)
 ```
 
PureDI vs. Container
 
 1. PureDI의 장점
 fatalError가 사라집니다.

 지금 구조는 등록을 빠뜨려도 컴파일이 됩니다. 실행 중에 그 화면에 들어가야 크래시하죠. Pure DI는 생성자에 인자를 안 넣으면 컴파일 에러입니다. 조립 누락이 빌드 단계에서 잡혀요.
 String(describing:)으로 이름 충돌이 날 여지도 없어지고요.

 2. 지금 방식에서 PureDI로 전환시 세 가지 단점

 1. 지연 생성 — didFinishLaunching에서 전부 만들어집니다. 알약 탭에 안 들어가도 PillUseCase가 생성되죠. 지금 앱 규모면 체감 안 될 수 있지만, SDK 초기화까지 있는 자리라 런치 타임은 계속 신경 쓰이는 부분입니다.
 2. 재등록 — 테스트에서 Mock으로 갈아끼우는 게 안 됩니다. 그럼 테스트마다 조립 코드를 따로 써야 해요.
 3. 순환 참조 처리 - 순환 참조가 많아지면 해결은 가능하지만 순서 관리가 너무 복잡해진다는 문제가 있다.
 
 3은 의존성에 따라 순서를 잘 배선하면 처리 가능하지만 코드가 복잡해진다는 문제점이 있다.
 // 의존성이 늘어날수록 조립 순서를 손으로 관리하지 않아도 된다는 점이 컨테이너의 이점이다.
 // 단, 생성자끼리 진짜 순환하면 resolve 가 무한 재귀에 빠지므로(캐시는 생성 완료 후 저장됨)
 // 양방향 배선은 반드시 생성 후 프로퍼티 주입으로 끊는다 — useCase ↔ watchSync 참고.
 */
