import SwiftUI
import TimerDomain

// 잠금화면 커스텀 알림 UI (e0iD7H 모양) — WKNotificationScene 이 로컬 알림 발화 시 렌더.
// 상단 시각/앱명 sash 와 하단 액션 버튼([완료])은 시스템이 그린다. 여기선 중앙 컨텐츠(종+타이머명)만.
struct AlarmNotificationView: View {
    let label: String
    let category: TimerCategory

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(WT.ringingBg)
                WIcon(name: "ic_bell", size: 26, color: WT.bell)
            }
            .frame(width: 54, height: 54)

            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(WT.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)

            Text(category.displayName)
                .font(.caption2)
                .foregroundStyle(WT.category(category))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
