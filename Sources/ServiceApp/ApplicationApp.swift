import SwiftUI
import Feature

@main
struct ApplicationApp: App {
    @State private var appState = AppState()
    @State private var appRouter = AppRouter()
    @State private var diContainer = AppDIContainer()

    init() {
        // 번들에 포함된 커스텀 폰트 등록 (Tuist 생성: TuistFonts+ServiceApp).
        // raw `Font.custom(...)` 이 정상 로드되려면 런치 시 한 번 호출해야 함.
        ServiceAppFontFamily.registerAllCustomFonts()
        #if DEBUG
        print("DEBUG Pretendard registered:", UIFont.fontNames(forFamilyName: "Pretendard"))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                appState: appState,
                appRouter: appRouter,
                diContainer: diContainer
            )
            // 푸시알림 · 유니버설 링크 등은 여기서 appRouter.handle(_:) 호출
            // (메인 진입 전이면 appRouter.enqueue(_:) 로 보류)
        }
    }
}
