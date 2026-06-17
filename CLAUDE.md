# Application Template

Tuist 4.x + SwiftUI 기반 iOS 앱 템플릿 프로젝트.

## 아키텍처

- **MVVM** — `@Observable` 매크로 기반 ViewModel
- **Navigation** — 3계층 정책 (앱 단계 / 탭+딥링크 / 탭 내부 스택). 아래 "화면 이동 정책" 참고
- **Repository** — 프로토콜 추상화로 데이터 소스 분리
- **DI** — `AppDIContainer` 프로토콜 기반 의존성 주입
- **Swift Concurrency** — `async/await`, `Actor` 기반 네트워크
- **Swift 6** — `Sendable` 준수, strict concurrency

## 아키텍처 패턴 규칙

### MVVM

- **View**: UI 선언만 담당. 비즈니스 로직 금지. 데이터는 ViewModel 프로퍼티에서 읽고, 액션은 ViewModel 메서드로 전달.
- **ViewModel**: `@Observable` 매크로 사용. 데이터 가공 후 View에 제공. Repository 프로토콜로만 데이터 소스에 접근.
- **소유권**: `@Observable` 객체는 한 곳에서만 소유. 자식 View는 `let`으로 전달받고, 바인딩 필요시 body에서 `@Bindable var x = x` 생성.
- **View에서 직접** Repository·NetworkClient 접근 금지.

### Repository

- 프로토콜은 `Shared/Domain/Interfaces/`에 정의.
- 구현체는 `Shared/Data/`에 둔다.
- ViewModel은 프로토콜에만 의존, 구현체는 `AppDIContainer`가 주입.
- DTO↔Entity 변환은 Repository 구현체 내부에서만 수행.

### DI (의존성 주입)

- `AppDIContainer`가 모든 의존성을 조립.
- ViewModel Factory 패턴으로 ViewModel 생성 시 필요한 Repository를 주입.
- ServiceApp 모듈에서만 구체적인 구현체를 알고, Feature는 프로토콜만 참조.

### Navigation (3계층)

1. **앱 단계**: `AppState.currentPhase` → `switch`로 화면 교체 (splash→main 등)
2. **탭/딥링크**: `AppRouter` → `selectedTab` 전환 + 교차 탭 진입
3. **탭 내부**: 각 탭 Router → `NavigationPath`로 push/pop

자세한 규칙은 아래 "화면 이동 정책" 참고.

### Concurrency

- `async/await` 기반. Completion handler 패턴 사용 금지.
- 네트워크 계층은 `Actor`로 격리.
- Swift 6 strict concurrency 준수, `Sendable` 명시.

## 모듈 구조

```
ServiceApp (app)
  └── depends on → Feature (static framework)
                     └── depends on → Shared (static framework)
```

| 모듈 | 타입 | 역할 |
|------|------|------|
| **Shared** | Static Framework | Core, Domain, Data — 재사용 가능한 기반 코드 |
| **Feature** | Static Framework | 화면 단위 (View + ViewModel + Navigation) |
| **ServiceApp** | App | 진입점, DI 컨테이너, Resources |

### Shared
```
Sources/Shared/
├── Core/          # DesignSystem, Network, Storage, Extensions
├── Domain/        # Entities, Interfaces(프로토콜)
└── Data/          # DTOs, Repository 구현체
```

데이터 흐름은 **ViewModel → Repository(프로토콜) → NetworkClient**로 짧게 유지한다.
UseCase·DataSource 레이어는 두지 않는다 (단일 소스 규모에선 과함).
ViewModel은 Repository **프로토콜**에만 의존하고, 구현체는 `AppDIContainer`가 주입한다.
DTO↔Entity 변환은 Repository 구현체(`Data/`)에 가둔다 — API 응답이 바뀌어도 `Item`은 그대로.

### Feature
```
Sources/Feature/
├── Home/          # HomeNavigationView + HomeView + HomeViewModel + HomeRouter + HomeRoute
├── Explore/       # 〃
├── Settings/      # 〃
├── Detail/        # DetailView + DetailViewModel
├── Tab/           # MainTab(enum), MainTabView
└── Navigation/    # AppRouter, DeepLink
```

### ServiceApp
```
Sources/ServiceApp/
├── ApplicationApp.swift   # @main 진입점, AppState·AppRouter·DIContainer 소유
├── RootView.swift         # AppPhase 분기 (splash/onboarding/auth/maintenance/main)
├── AppState.swift         # 앱 단계(AppPhase) 상태머신
└── AppDIContainer.swift   # 의존성 조립
```

## 화면 이동 정책

3계층으로 책임을 분리한다. 계층마다 도구가 고정 — 섞지 않는다.

| 계층 | 소유자 | 도구 | 용도 |
|------|--------|------|------|
| ① 앱 단계 | `AppState.currentPhase` | `switch`로 화면 교체 | splash→onboarding/auth/maintenance→main (되돌릴 수 없는 흐름) |
| ② 탭 / 딥링크 | `AppRouter` | `selectedTab` + 탭 라우터 소유 | 탭 전환, 교차 탭 진입 |
| ③ 탭 내부 | `HomeRouter` 등 | `NavigationPath` (path) + sheet | push/pop/popToRoot, 모달 |

**규칙**
1. `AppRouter`가 탭별 라우터(`home`/`explore`/`settings`)를 **소유**하고 각 `*NavigationView`에 주입한다. NavigationView는 라우터를 직접 생성하지 않는다.
2. **교차 탭 이동은 `AppRouter.handle(DeepLink)`가 유일한 진입점.** 푸시알림·유니버설 링크·위젯 매핑을 여기 한 곳에 모은다. 메인 진입 전 도착한 링크는 `enqueue(_:)` → `flushPendingLink()`로 처리.
3. **정방향 데이터**(앞→뒤): `Route`의 associated value(Hashable한 식별값)로 전달, ViewModel은 `make…ViewModel` factory로 조립. **클로저·ViewModel은 `Route`에 넣지 않는다**(NavigationPath는 Hashable 요구).
4. **역방향 데이터**(뒤→앞, 결과 반영): 기본은 **공유 Repository**(목록·상세가 같은 소스를 봐 자동 동기화). 휘발성 단발 선택(picker 등)만 예외적으로 factory에 콜백 주입.
5. `@Observable` 객체는 **한 곳에서만 소유**. 자식 View는 `let`으로 받아 읽고, 바인딩이 필요하면 body에서 `@Bindable var x = x`로 만든다.

## 다국어 지원 (i18n)

**String Catalog (`.xcstrings`)** 기반, `AppStrings` enum으로 타입-세이프하게 접근한다.

### 구조

- **String Catalog**: `Sources/Shared/Resources/Localizable.xcstrings` — 모든 언어의 문자열 중앙 관리
- **타입-세이프 enum**: `Sources/Shared/Core/DesignSystem/AppStrings.swift` — 중첩 enum으로 컴파일 타임 보장
- 소스 언어: 한국어(ko), 기본 영어(en) 번역 포함

### 규칙

1. 사용자에게 보이는 모든 문자열은 `AppStrings` enum에서 가져온다. `Text("문자열")` 하드코딩 금지.
2. SwiftUI 자동 현지화(`Text("Hello")`)에 의존하지 않는다 — 반드시 명시적 enum 사용.
3. `String(localized:bundle:)` + `.module`로 런타임 로케일 변경을 반영한다.
4. 키 이름 규칙: `{화면}.{용도}` (예: `onboarding.welcome`), `AppStrings` 중첩 enum과 1:1 매핑.

```swift
// ✅
Text(AppStrings.Tab.home)
.navigationTitle(AppStrings.Home.navigationTitle)

// ❌
Text("홈")
.navigationTitle("Application")
```

### 새 문자열 추가 절차

1. `Localizable.xcstrings` 에 키-값 추가
2. `AppStrings.swift` 에 static property 추가
3. 코드에서 `AppStrings.Xxx.yyy` 사용

자세한 규칙은 `.claude/rules/localization.md` 참고.

## 새 프로젝트 시작 체크리스트

이 템플릿을 복사해서 새 앱을 만들 때 아래 항목을 반드시 변경하세요.
모듈명과 폴더 구조는 고정 — 변경하지 마세요.

### 🔴 필수 변경

| 순서 | 항목 | 파일 | 현재값 | 변경 예시 |
|------|------|------|--------|----------|
| 1 | **번들ID** | `Project.swift` 상단 `bundleId` | `app.kyulabs.template` | `app.kyulabs.myapp` |
| 2 | **개발팀** | `Project.swift` → `DEVELOPMENT_TEAM` | `""` | `"ABCDE12345"` |

번들ID는 `Project.swift` 최상단에 1개만 정의하면 됩니다:
```swift
let bundleId = "app.kyulabs.template"  // ← 이것만 변경
```
Shared와 Feature는 자동으로 `.shared`, `.feature` suffix가 붙습니다.

### 🟡 앱마다 커스텀

| 항목 | 파일 | 설명 |
|------|------|------|
| 브랜드 컬러 | `Shared/Core/DesignSystem/AppColor.swift` → `Brand` | primary, accent 등 |
| 폰트 | `Shared/Core/DesignSystem/AppTypography.swift` | Pretendard → 커스텀 폰트 시 수정 |
| 이미지 | `Shared/Core/DesignSystem/AppImage.swift` + `Resources/Assets.xcassets` | case 추가 후 imageset 매핑 |
| 다국어 문자열 | `Shared/Core/DesignSystem/AppStrings.swift` + `Shared/Resources/Localizable.xcstrings` | 키-값 추가 후 enum 매핑 |
| API 서버 URL | `Shared/Core/Network/APIEndpoint.swift` → `baseURL` 기본값 | 실제 API 서버 주소 |
| API 엔드포인트 | `Shared/Core/Network/APIEndpoint.swift` | 앱에 맞는 엔드포인트 추가 |
| UserDefaults 키 | `Shared/Core/Storage/UserDefaultsStore.swift` → `Keys` | 앱별 저장 키 |
| 앱 아이콘 | `Resources/Assets.xcassets/AppIcon.appiconset` | 1024x1024 아이콘 |
| 강조색 | `Resources/Assets.xcassets/AccentColor.colorset` | 앱 브랜드 컬러 |

### 🟢 필요시 변경

| 항목 | 파일 | 설명 |
|------|------|------|
| 앱 버전 | `Project.swift` → `MARKETING_VERSION` | 기본값 1.0.0 |
| 빌드 번호 | `Project.swift` → `CURRENT_PROJECT_VERSION` | 기본값 1 |
| 최소 iOS 버전 | `Project.swift` → `deploymentTargets` | 기본값 26.0 |
| 지원 기기 | `Project.swift` → `destinations` | 기본값 iPhone, iPad |
| 화면 회전 | `Project.swift` → `UISupportedInterfaceOrientations` | 기본값 세로+가로 |

## 명령어

```bash
tuist generate          # Xcode 프로젝트 생성
tuist edit              # Xcode에서 매니페스트 편집
tuist build             # 전체 빌드
tuist clean             # 캐시 정리
```
