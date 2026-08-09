import SwiftUI

/*
 폰이 iOS 26.1 미만일 때의 워치 안내 — 타이머 UI 대체.

 타이머는 AlarmKit(26.1+) 전용이다. 그 미만 폰에서는 타이머를 만들 수 없으므로 워치가
 프리셋·리스트를 정상처럼 보여주면 안 된다. 예전에는 프리셋을 눌렀을 때 "알람 권한이
 필요해요"라는 알림이 떴는데, 폰에서 권한을 켤 방법이 없어 막다른 길이었다.

 폰 안내 화면(TimerUnavailableVC)과 같은 메시지를 준다.
 */
struct WatchUnsupportedView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 26))
                .foregroundStyle(WT.bell)

            Text("iOS 26.1 이상 필요")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WT.textPrimary)

            Text("무음·잠금에서도 확실히 울리는 시스템 알람을 쓰기 위해 아이폰이 iOS 26.1 이상이어야 해요.")
                .font(.system(size: 12))
                .foregroundStyle(WT.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
    }
}
